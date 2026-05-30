import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:one_remote/app/analytics/analytics_service.dart';
import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_product_ids.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/monetization/restore_purchases_outcome.dart';
import 'package:one_remote/app/monetization/shared_prefs_pro_entitlement_cache.dart';

/// Application service exposing Pro entitlement for UI and feature gates.
final class ProEntitlementService {
  ProEntitlementService({
    required this._repository,
    required this._cache,
  }) {
    _subscription = _repository.entitlementStream.listen(_onRepositoryStatus);
  }

  final ProEntitlementRepository _repository;
  final SharedPrefsProEntitlementCache _cache;
  late final StreamSubscription<ProEntitlementStatus> _subscription;

  final ValueNotifier<ProEntitlementStatus> statusNotifier = ValueNotifier(
    ProEntitlementStatus.unknown,
  );
  final ValueNotifier<bool> storeAvailableNotifier = ValueNotifier(false);
  final ValueNotifier<String?> activeProductIdNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> subscriptionExpiresAtNotifier = ValueNotifier(
    null,
  );

  bool get isPro => statusNotifier.value == ProEntitlementStatus.entitled;

  bool get hasLifetimePro =>
      isPro &&
      activeProductIdNotifier.value == ProProductIds.lifetime;

  /// Applies the last cached entitlement for immediate UI while verification runs.
  Future<void> applyLastKnownStatusFromCache() async {
    await _loadCachedSubscriptionMetadata();
    final cached = await _cache.readLastKnownStatus();
    if (cached != null) {
      statusNotifier.value = cached;
    }
    if (_isCachedSubscriptionExpired()) {
      statusNotifier.value = ProEntitlementStatus.unknown;
    }
  }

  /// Re-validates with the store after resume or cold start.
  Future<void> refreshFromStore({bool isDebugBuild = false}) async {
    reconcileExpiredSubscriptionFromCache();

    if (isDebugBuild && await _cache.readDebugEntitlementOverride()) {
      final cached = await _cache.readLastKnownStatus();
      if (cached != null) {
        statusNotifier.value = cached;
        storeAvailableNotifier.value = await _repository.isAvailable();
        return;
      }
    }

    // Keep cached entitled UI while the store re-validates; clearing to unknown
    // makes Pro flicker off when Play returns no restore events.
    if (statusNotifier.value != ProEntitlementStatus.entitled) {
      statusNotifier.value = ProEntitlementStatus.unknown;
    }
    final available = await _repository.isAvailable();
    storeAvailableNotifier.value = available;
    if (!available) {
      await _setResolvedStatus(ProEntitlementStatus.notEntitled);
      return;
    }
    try {
      await _repository.refreshEntitlement();
      if (statusNotifier.value == ProEntitlementStatus.unknown) {
        await _setResolvedStatus(ProEntitlementStatus.notEntitled);
      }
    } catch (_) {
      await _setResolvedStatus(ProEntitlementStatus.notEntitled);
    }
  }

  /// Drops cached subscription access when the saved renewal date has passed.
  ///
  /// Returns `true` when local entitlement was cleared before store refresh.
  bool reconcileExpiredSubscriptionFromCache() {
    if (!_isCachedSubscriptionExpired()) {
      return false;
    }
    unawaited(_setResolvedStatus(ProEntitlementStatus.notEntitled));
    return true;
  }

  Future<bool> purchasePro() async {
    return purchaseProduct(null);
  }

  Future<List<ProductDetails>> loadProProducts() async {
    if (!storeAvailableNotifier.value) {
      await refreshFromStore();
      if (!storeAvailableNotifier.value) {
        return const [];
      }
    }
    return _repository.queryProProductDetails();
  }

  Future<bool> purchaseProduct(String? productId) async {
    return _startPurchase(
      () => _repository.purchasePro(productId: productId),
    );
  }

  Future<bool> purchaseProductDetails(ProductDetails productDetails) async {
    return _startPurchase(
      () => _repository.purchasePro(productDetails: productDetails),
    );
  }

  Future<bool> _startPurchase(Future<void> Function() startPurchase) async {
    if (!storeAvailableNotifier.value) {
      await refreshFromStore();
      if (!storeAvailableNotifier.value) {
        return false;
      }
    }
    statusNotifier.value = ProEntitlementStatus.unknown;
    try {
      await startPurchase();
      return true;
    } catch (_) {
      await _setResolvedStatus(ProEntitlementStatus.notEntitled);
      return false;
    }
  }

  /// Debug-only: flip between entitled and not entitled without the store.
  Future<void> debugToggleEntitlement() async {
    final next = statusNotifier.value == ProEntitlementStatus.entitled
        ? ProEntitlementStatus.notEntitled
        : ProEntitlementStatus.entitled;
    await _cache.writeDebugEntitlementOverride(
      next == ProEntitlementStatus.entitled,
    );
    await _setResolvedStatus(next);
  }

  Future<RestorePurchasesOutcome> restorePurchases({
    Duration resolutionTimeout = const Duration(seconds: 25),
  }) async {
    if (!storeAvailableNotifier.value) {
      await refreshFromStore();
      if (!storeAvailableNotifier.value) {
        return RestorePurchasesOutcome.storeUnavailable;
      }
    }

    if (statusNotifier.value == ProEntitlementStatus.entitled) {
      // Play often returns no purchase events when Pro is already active; re-running
      // restore would falsely emit notEntitled from the repository.
      return RestorePurchasesOutcome.alreadyActive;
    }

    statusNotifier.value = ProEntitlementStatus.unknown;
    final wait = _startWaitForResolvedStatus(timeout: resolutionTimeout);
    try {
      await _repository.restorePurchases();
      final status = await wait.future;
      return switch (status) {
        ProEntitlementStatus.entitled => RestorePurchasesOutcome.restored,
        ProEntitlementStatus.notEntitled =>
          RestorePurchasesOutcome.noPurchasesFound,
        ProEntitlementStatus.unknown => RestorePurchasesOutcome.failed,
      };
    } on ProRestoreValidationFailedException {
      wait.cancel();
      if (statusNotifier.value == ProEntitlementStatus.unknown) {
        await _setResolvedStatus(ProEntitlementStatus.notEntitled);
      }
      return RestorePurchasesOutcome.failed;
    } catch (_) {
      wait.cancel();
      if (statusNotifier.value == ProEntitlementStatus.unknown) {
        await _setResolvedStatus(ProEntitlementStatus.notEntitled);
      }
      return RestorePurchasesOutcome.failed;
    }
  }

  _ResolvedStatusWait _startWaitForResolvedStatus({
    required Duration timeout,
  }) {
    final completer = Completer<ProEntitlementStatus>();
    void listener() {
      final status = statusNotifier.value;
      if (status == ProEntitlementStatus.unknown) {
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(status);
      }
    }

    final current = statusNotifier.value;
    if (current != ProEntitlementStatus.unknown) {
      return _ResolvedStatusWait(Future.value(current), () {});
    }

    statusNotifier.addListener(listener);
    final future = completer.future
        .timeout(
          timeout,
          onTimeout: () {
            if (!completer.isCompleted) {
              completer.complete(ProEntitlementStatus.unknown);
            }
            return ProEntitlementStatus.unknown;
          },
        )
        .whenComplete(() => statusNotifier.removeListener(listener));
    return _ResolvedStatusWait(future, () {
      if (!completer.isCompleted) {
        completer.complete(ProEntitlementStatus.unknown);
      }
      statusNotifier.removeListener(listener);
    });
  }

  Future<void> _onRepositoryStatus(ProEntitlementStatus status) async {
    if (status == ProEntitlementStatus.unknown) {
      statusNotifier.value = status;
      return;
    }
    if (status == ProEntitlementStatus.entitled) {
      await _cache.writeDebugEntitlementOverride(false);
      final productId = _repository.activeProductId;
      if (productId != null) {
        activeProductIdNotifier.value = productId;
        await _cache.writeActiveProductId(productId);
      }
      await _syncSubscriptionExpiresAt(_repository.subscriptionExpiresAt);
    }
    await _setResolvedStatus(status);

    final sl = GetIt.instance;
    if (sl.isRegistered<AnalyticsService>()) {
      unawaited(
        sl<AnalyticsService>().proEntitlementChanged(status: status.name),
      );
    }
  }

  Future<void> _setResolvedStatus(ProEntitlementStatus status) async {
    statusNotifier.value = status;
    if (status != ProEntitlementStatus.entitled) {
      activeProductIdNotifier.value = null;
      subscriptionExpiresAtNotifier.value = null;
    }
    await _cache.writeStatus(status);
  }

  Future<void> _loadCachedSubscriptionMetadata() async {
    final productId = await _cache.readActiveProductId();
    if (productId != null) {
      activeProductIdNotifier.value = productId;
    }
    final expiresAt = await _cache.readSubscriptionExpiresAt();
    if (expiresAt != null) {
      subscriptionExpiresAtNotifier.value = expiresAt;
    }
  }

  Future<void> _syncSubscriptionExpiresAt(DateTime? expiresAt) async {
    subscriptionExpiresAtNotifier.value = expiresAt;
    if (expiresAt == null) {
      await _cache.clearSubscriptionExpiresAt();
      return;
    }
    await _cache.writeSubscriptionExpiresAt(expiresAt);
  }

  bool _isCachedSubscriptionExpired() {
    if (statusNotifier.value != ProEntitlementStatus.entitled) {
      return false;
    }
    if (hasLifetimePro) {
      return false;
    }
    final expiresAt = subscriptionExpiresAtNotifier.value;
    if (expiresAt == null) {
      return false;
    }
    return !expiresAt.isAfter(DateTime.now());
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    _repository.dispose();
    statusNotifier.dispose();
    storeAvailableNotifier.dispose();
    activeProductIdNotifier.dispose();
    subscriptionExpiresAtNotifier.dispose();
  }
}

final class _ResolvedStatusWait {
  const _ResolvedStatusWait(this.future, this.cancel);

  final Future<ProEntitlementStatus> future;
  final VoidCallback cancel;
}
