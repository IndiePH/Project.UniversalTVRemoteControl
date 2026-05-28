import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';

import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/monetization/pro_receipt_validation_service.dart';

/// Store-backed entitlement source using Google Play Billing / StoreKit.
final class StoreProEntitlementRepository implements ProEntitlementRepository {
  StoreProEntitlementRepository({
    InAppPurchase? inAppPurchase,
    required String defaultProductId,
    List<String>? productIds,
    Duration restoreWait = const Duration(seconds: 2),
    ProReceiptValidationService? receiptValidationService,
  }) : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
       _defaultProductId = defaultProductId,
       _productIds = (productIds == null || productIds.isEmpty)
           ? <String>[defaultProductId]
           : <String>{...productIds, defaultProductId}.toList(growable: false),
       _restoreWait = restoreWait,
       _receiptValidationService = receiptValidationService {
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
  final Map<String, ProductDetails> _cachedProductDetails = {};
  bool? _cachedAvailability;
  bool _entitledSeenDuringRefresh = false;

  @override
  Stream<ProEntitlementStatus> get entitlementStream => _controller.stream;

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
    _entitledSeenDuringRefresh = false;
    await _inAppPurchase.restorePurchases();
    await Future<void>.delayed(_restoreWait);
    if (!_entitledSeenDuringRefresh) {
      _controller.add(ProEntitlementStatus.notEntitled);
    }
  }

  @override
  Future<void> purchasePro({String? productId}) async {
    final available = await isAvailable();
    if (!available) {
      throw StateError('In-app purchase is unavailable on this device.');
    }
    final id = (productId?.trim().isNotEmpty ?? false)
        ? productId!.trim()
        : _defaultProductId;
    final product = await _ensureProductLoaded(id);
    final didStart = await _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!didStart) {
      throw StateError('Failed to start the purchase flow.');
    }
  }

  @override
  Future<void> restorePurchases() async {
    final available = await isAvailable();
    if (!available) {
      _controller.add(ProEntitlementStatus.notEntitled);
      return;
    }
    _entitledSeenDuringRefresh = false;
    await _inAppPurchase.restorePurchases();
    await Future<void>.delayed(_restoreWait);
    if (!_entitledSeenDuringRefresh) {
      _controller.add(ProEntitlementStatus.notEntitled);
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

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    var hasEntitlement = false;
    for (final purchase in updates) {
      if (!_productIds.contains(purchase.productID)) {
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final entitled = await _validateIfPossible(purchase);
          hasEntitlement = hasEntitlement || entitled;
          if (entitled) {
            _entitledSeenDuringRefresh = true;
          }
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
        case PurchaseStatus.pending:
          _controller.add(ProEntitlementStatus.unknown);
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
      }
    }

    if (hasEntitlement) {
      _controller.add(ProEntitlementStatus.entitled);
    } else if (updates.any((purchase) => _productIds.contains(purchase.productID))) {
      _controller.add(ProEntitlementStatus.notEntitled);
    }
  }

  Future<bool> _validateIfPossible(PurchaseDetails purchase) async {
    // Android-only receipt validation for now.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final validator = _receiptValidationService;
    if (validator == null) {
      // If not configured, keep current local-only behavior.
      return true;
    }

    final token = purchase.verificationData.serverVerificationData.trim();
    if (token.isEmpty) {
      return false;
    }
    try {
      return await validator.verifyAndroidNonConsumable(
        productId: purchase.productID,
        purchaseToken: token,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription.cancel());
    _controller.close();
  }
}
