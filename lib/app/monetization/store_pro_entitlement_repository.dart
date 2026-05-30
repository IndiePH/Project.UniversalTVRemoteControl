import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_product_ids.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/monetization/pro_receipt_validation_result.dart';
import 'package:one_remote/app/monetization/pro_receipt_validation_service.dart';
import 'package:one_remote/app/monetization/restore_purchases_outcome.dart';

/// Store-backed entitlement source using Google Play Billing / StoreKit.
final class StoreProEntitlementRepository implements ProEntitlementRepository {
  StoreProEntitlementRepository({
    InAppPurchase? inAppPurchase,
    required String defaultProductId,
    List<String>? productIds,
    this._restoreWait = const Duration(seconds: 2),
    this._receiptValidationService,
  }) : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
       _defaultProductId = defaultProductId,
       _productIds = (productIds == null || productIds.isEmpty)
           ? <String>[defaultProductId]
           : <String>{...productIds, defaultProductId}.toList(growable: false) {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (error, stackTrace) =>
          _controller.add(ProEntitlementStatus.notEntitled),
    );
  }

  final InAppPurchase _inAppPurchase;
  final String _defaultProductId;
  final List<String> _productIds;
  final Duration _restoreWait;
  final ProReceiptValidationService? _receiptValidationService;
  final StreamController<ProEntitlementStatus> _controller =
      StreamController<ProEntitlementStatus>.broadcast();

  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  Future<void>? _purchaseProcessingChain;
  final Map<String, ProductDetails> _cachedProductDetails = {};
  bool? _cachedAvailability;
  bool _entitledSeenDuringRefresh = false;
  bool _receivedRelevantPurchasesDuringRestore = false;
  bool _validationFailedDuringRestore = false;
  bool _explicitRestoreInProgress = false;
  int _pendingValidations = 0;
  String? _activeProductId;
  DateTime? _subscriptionExpiresAt;

  @override
  Stream<ProEntitlementStatus> get entitlementStream => _controller.stream;

  @override
  String? get activeProductId => _activeProductId;

  @override
  DateTime? get subscriptionExpiresAt => _subscriptionExpiresAt;

  @override
  Future<bool> isAvailable() async {
    if (_cachedAvailability != null) {
      return _cachedAvailability!;
    }
    _cachedAvailability = await _inAppPurchase.isAvailable();
    return _cachedAvailability!;
  }

  @override
  Future<void> refreshEntitlement() async {
    final available = await isAvailable();
    if (!available) {
      _controller.add(ProEntitlementStatus.notEntitled);
      return;
    }

    await _ensureProductsLoaded();
    await _restoreAndResolveEntitlement(treatEmptyAsNotEntitled: false);
  }

  @override
  Future<void> purchasePro({
    String? productId,
    ProductDetails? productDetails,
  }) async {
    final available = await isAvailable();
    if (!available) {
      throw StateError('In-app purchase is unavailable on this device.');
    }
    final ProductDetails product;
    if (productDetails != null) {
      product = productDetails;
      _cachedProductDetails[product.id] = product;
    } else {
      final id = (productId?.trim().isNotEmpty ?? false)
          ? productId!.trim()
          : _defaultProductId;
      product = await _ensureProductLoaded(id);
    }
    final purchaseParam = _purchaseParamFor(product);
    final didStart = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
    if (!didStart) {
      throw StateError('Failed to start the purchase flow.');
    }
  }

  PurchaseParam _purchaseParamFor(ProductDetails product) {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        product is GooglePlayProductDetails) {
      return GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: product.offerToken,
      );
    }
    return PurchaseParam(productDetails: product);
  }

  @override
  Future<List<ProductDetails>> queryProProductDetails() async {
    final available = await isAvailable();
    if (!available) {
      return const [];
    }
    await _ensureProductsLoaded();
    return _productIds
        .map((id) => _cachedProductDetails[id])
        .whereType<ProductDetails>()
        .toList(growable: false);
  }

  @override
  Future<void> restorePurchases() async {
    final available = await isAvailable();
    if (!available) {
      _controller.add(ProEntitlementStatus.notEntitled);
      return;
    }
    _explicitRestoreInProgress = true;
    try {
      await _restoreAndResolveEntitlement(treatEmptyAsNotEntitled: true);
    } finally {
      _explicitRestoreInProgress = false;
    }
  }

  Future<void> _restoreAndResolveEntitlement({
    required bool treatEmptyAsNotEntitled,
  }) async {
    _entitledSeenDuringRefresh = false;
    _receivedRelevantPurchasesDuringRestore = false;
    _validationFailedDuringRestore = false;
    await _inAppPurchase.restorePurchases();
    await _awaitPurchaseProcessingComplete();
    if (!_entitledSeenDuringRefresh &&
        treatEmptyAsNotEntitled &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      await _queryAndroidPastPurchasesFallback();
      await _awaitPurchaseProcessingComplete();
    }
    if (_entitledSeenDuringRefresh) {
      return;
    }
    if (_validationFailedDuringRestore && treatEmptyAsNotEntitled) {
      throw const ProRestoreValidationFailedException();
    }
    // Empty restore responses are common on Android when purchases are already
    // acknowledged; only infer "no purchases" on an explicit restore attempt.
    if (_receivedRelevantPurchasesDuringRestore ||
        treatEmptyAsNotEntitled) {
      _controller.add(ProEntitlementStatus.notEntitled);
    }
  }

  Future<void> _queryAndroidPastPurchasesFallback() async {
    try {
      final addition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) {
        developer.log(
          'queryPastPurchases failed: ${response.error!.message}',
          name: 'ProEntitlement',
          level: 1000,
        );
        _validationFailedDuringRestore = true;
        return;
      }
      final relevantPurchases = response.pastPurchases
          .where((purchase) => _productIds.contains(purchase.productID))
          .map(
            (purchase) => purchase..status = PurchaseStatus.restored,
          )
          .toList(growable: false);
      if (relevantPurchases.isEmpty) {
        return;
      }
      _receivedRelevantPurchasesDuringRestore = true;
      final result = await _processPurchases(relevantPurchases);
      _applyPurchaseProcessResult(result);
    } catch (error, stackTrace) {
      developer.log(
        'queryPastPurchases fallback failed: $error',
        name: 'ProEntitlement',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
      _validationFailedDuringRestore = true;
    }
  }

  /// Waits for the purchase stream and in-flight receipt validation to settle.
  Future<void> _awaitPurchaseProcessingComplete({
    Duration maxWait = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(maxWait);
    await Future<void>.delayed(_restoreWait);
    while (DateTime.now().isBefore(deadline)) {
      if (_pendingValidations == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (_pendingValidations == 0) {
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _ensureProductsLoaded() async {
    final missing = _productIds.where((id) => !_cachedProductDetails.containsKey(id));
    if (missing.isEmpty) {
      return;
    }
    final response = await _inAppPurchase.queryProductDetails(_productIds.toSet());
    for (final item in response.productDetails) {
      _cachedProductDetails[item.id] = item;
    }
  }

  Future<ProductDetails> _ensureProductLoaded(String id) async {
    final cached = _cachedProductDetails[id];
    if (cached != null) {
      return cached;
    }
    final response = await _inAppPurchase.queryProductDetails({id});
    if (response.notFoundIDs.contains(id) || response.productDetails.isEmpty) {
      throw StateError('Pro product "$id" is not configured.');
    }
    final found = response.productDetails.firstWhere(
      (item) => item.id == id,
      orElse: () => response.productDetails.first,
    );
    _cachedProductDetails[id] = found;
    return found;
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> updates) {
    final previous = _purchaseProcessingChain ?? Future<void>.value();
    _purchaseProcessingChain = previous
        .then((_) => _handlePurchaseUpdates(updates))
        .catchError((Object error, StackTrace stackTrace) {
          developer.log(
            'Pro purchase update processing failed: $error',
            name: 'ProEntitlement',
            level: 1000,
            error: error,
            stackTrace: stackTrace,
          );
        });
    return _purchaseProcessingChain!;
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> updates) async {
    final result = await _processPurchases(updates);
    _applyPurchaseProcessResult(result);
  }

  Future<_PurchaseProcessResult> _processPurchases(
    List<PurchaseDetails> updates,
  ) async {
    var hasEntitlement = false;
    var sawRelevantUpdate = false;
    var sawPendingUpdate = false;
    String? entitledProductId;
    int? entitledExpiresAtEpochMs;
    for (final purchase in updates) {
      if (!_productIds.contains(purchase.productID)) {
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        continue;
      }
      sawRelevantUpdate = true;
      _receivedRelevantPurchasesDuringRestore = true;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            final validation = await _validatePurchaseWithRetry(purchase);
            hasEntitlement = hasEntitlement || validation.entitled;
            if (validation.entitled) {
              _entitledSeenDuringRefresh = true;
              entitledProductId =
                  validation.resolvedProductId ?? purchase.productID;
              entitledExpiresAtEpochMs = _laterExpiryEpochMs(
                entitledExpiresAtEpochMs,
                validation.expiresAtEpochMs,
              );
              if (purchase.productID == ProProductIds.lifetime) {
                break;
              }
            } else {
              _validationFailedDuringRestore = true;
            }
          } catch (error, stackTrace) {
            _validationFailedDuringRestore = true;
            developer.log(
              'Pro purchase validation error (productId=${purchase.productID}): '
              '$error',
              name: 'ProEntitlement',
              level: 1000,
              error: error,
              stackTrace: stackTrace,
            );
          }
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
        case PurchaseStatus.pending:
          sawPendingUpdate = true;
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
      }
    }

    return _PurchaseProcessResult(
      hasEntitlement: hasEntitlement,
      sawRelevantUpdate: sawRelevantUpdate,
      sawPendingUpdate: sawPendingUpdate,
      entitledProductId: entitledProductId,
      entitledExpiresAtEpochMs: entitledExpiresAtEpochMs,
    );
  }

  void _applyPurchaseProcessResult(_PurchaseProcessResult result) {
    if (result.hasEntitlement) {
      _activeProductId = result.entitledProductId;
      _subscriptionExpiresAt = _dateTimeFromEpochMs(
        result.entitledExpiresAtEpochMs,
      );
      _controller.add(ProEntitlementStatus.entitled);
      return;
    }
    if (result.sawPendingUpdate) {
      _controller.add(ProEntitlementStatus.unknown);
      return;
    }
    if (result.sawRelevantUpdate) {
      if (_validationFailedDuringRestore && _explicitRestoreInProgress) {
        return;
      }
      _activeProductId = null;
      _subscriptionExpiresAt = null;
      _controller.add(ProEntitlementStatus.notEntitled);
    }
  }

  Future<ProReceiptValidationResult> _validatePurchaseWithRetry(
    PurchaseDetails purchase,
  ) async {
    _pendingValidations++;
    try {
      ProReceiptValidationResult lastResult =
          const ProReceiptValidationResult.notEntitled();
      for (var attempt = 0; attempt < 2; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        lastResult = await _validatePurchaseOnce(purchase);
        if (lastResult.entitled) {
          return lastResult;
        }
      }
      return lastResult;
    } finally {
      _pendingValidations--;
    }
  }

  Future<ProReceiptValidationResult> _validatePurchaseOnce(
    PurchaseDetails purchase,
  ) async {
    // Android-only receipt validation for now.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return ProReceiptValidationResult(
        entitled: true,
        resolvedProductId: purchase.productID,
      );
    }
    final validator = _receiptValidationService;
    if (validator == null) {
      developer.log(
        'Pro receipt validation skipped: service not configured '
        '(productId=${purchase.productID})',
        name: 'ProEntitlement',
        level: 900,
      );
      // If not configured, keep current local-only behavior.
      return ProReceiptValidationResult(
        entitled: true,
        resolvedProductId: purchase.productID,
      );
    }

    final token = _androidPurchaseToken(purchase);
    if (token == null || token.isEmpty) {
      developer.log(
        'Pro receipt validation skipped: empty purchase token '
        '(productId=${purchase.productID})',
        name: 'ProEntitlement',
        level: 1000,
      );
      if (kDebugMode) {
        debugPrint(
          'Pro receipt validation skipped: empty purchase token '
          '(productId=${purchase.productID})',
        );
      }
      return const ProReceiptValidationResult.notEntitled();
    }
    try {
      return await validator.verifyAndroidPurchase(
        productId: purchase.productID,
        purchaseToken: token,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Pro receipt validation failed for ${purchase.productID}: $error',
        );
        debugPrint('$stackTrace');
      }
      return const ProReceiptValidationResult.notEntitled();
    }
  }

  int? _laterExpiryEpochMs(int? current, int? candidate) {
    if (candidate == null) {
      return current;
    }
    if (current == null) {
      return candidate;
    }
    return candidate > current ? candidate : current;
  }

  DateTime? _dateTimeFromEpochMs(int? epochMs) {
    if (epochMs == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }

  String? _androidPurchaseToken(PurchaseDetails purchase) {
    final fromServer = purchase.verificationData.serverVerificationData.trim();
    if (fromServer.isNotEmpty) {
      return fromServer;
    }
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        purchase is GooglePlayPurchaseDetails) {
      return purchase.billingClientPurchase.purchaseToken;
    }
    return null;
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription.cancel());
    _controller.close();
  }
}

final class _PurchaseProcessResult {
  const _PurchaseProcessResult({
    required this.hasEntitlement,
    required this.sawRelevantUpdate,
    required this.sawPendingUpdate,
    required this.entitledProductId,
    required this.entitledExpiresAtEpochMs,
  });

  final bool hasEntitlement;
  final bool sawRelevantUpdate;
  final bool sawPendingUpdate;
  final String? entitledProductId;
  final int? entitledExpiresAtEpochMs;
}
