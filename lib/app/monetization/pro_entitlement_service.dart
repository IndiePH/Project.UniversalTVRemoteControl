import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/monetization/shared_prefs_pro_entitlement_cache.dart';

/// Application service exposing Pro entitlement for UI and feature gates.
final class ProEntitlementService {
  ProEntitlementService({
    required ProEntitlementRepository repository,
    required SharedPrefsProEntitlementCache cache,
  }) : _repository = repository,
       _cache = cache {
    _subscription = _repository.entitlementStream.listen(_onRepositoryStatus);
  }

  final ProEntitlementRepository _repository;
  final SharedPrefsProEntitlementCache _cache;
  late final StreamSubscription<ProEntitlementStatus> _subscription;

  final ValueNotifier<ProEntitlementStatus> statusNotifier = ValueNotifier(
    ProEntitlementStatus.unknown,
  );
  final ValueNotifier<bool> storeAvailableNotifier = ValueNotifier(false);

  bool get isPro => statusNotifier.value == ProEntitlementStatus.entitled;

  Future<void> refreshFromStore() async {
    statusNotifier.value = ProEntitlementStatus.unknown;
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

  Future<bool> purchasePro() async {
    if (!storeAvailableNotifier.value) {
      await refreshFromStore();
      if (!storeAvailableNotifier.value) {
        return false;
      }
    }
    statusNotifier.value = ProEntitlementStatus.unknown;
    try {
      await _repository.purchasePro();
      return true;
    } catch (_) {
      await _setResolvedStatus(ProEntitlementStatus.notEntitled);
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    if (!storeAvailableNotifier.value) {
      await refreshFromStore();
      if (!storeAvailableNotifier.value) {
        return false;
      }
    }
    statusNotifier.value = ProEntitlementStatus.unknown;
    try {
      await _repository.restorePurchases();
      return true;
    } catch (_) {
      await _setResolvedStatus(ProEntitlementStatus.notEntitled);
      return false;
    }
  }

  Future<void> _onRepositoryStatus(ProEntitlementStatus status) async {
    if (status == ProEntitlementStatus.unknown) {
      statusNotifier.value = status;
      return;
    }
    await _setResolvedStatus(status);
  }

  Future<void> _setResolvedStatus(ProEntitlementStatus status) async {
    statusNotifier.value = status;
    await _cache.writeStatus(status);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    _repository.dispose();
    statusNotifier.dispose();
    storeAvailableNotifier.dispose();
  }
}
