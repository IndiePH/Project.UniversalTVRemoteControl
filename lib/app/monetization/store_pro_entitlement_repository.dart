import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';

/// Store-backed entitlement source using Google Play Billing / StoreKit.
final class StoreProEntitlementRepository implements ProEntitlementRepository {
  StoreProEntitlementRepository({
    InAppPurchase? inAppPurchase,
    required String productId,
    Duration restoreWait = const Duration(seconds: 2),
  }) : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
       _productId = productId,
       _restoreWait = restoreWait {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (error, stackTrace) =>
          _controller.add(ProEntitlementStatus.notEntitled),
    );
  }

  final InAppPurchase _inAppPurchase;
  final String _productId;
  final Duration _restoreWait;
  final StreamController<ProEntitlementStatus> _controller =
      StreamController<ProEntitlementStatus>.broadcast();

  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  ProductDetails? _cachedProductDetails;
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

    await _ensureProductLoaded();
    _entitledSeenDuringRefresh = false;
    await _inAppPurchase.restorePurchases();
    await Future<void>.delayed(_restoreWait);
    if (!_entitledSeenDuringRefresh) {
      _controller.add(ProEntitlementStatus.notEntitled);
    }
  }

  @override
  Future<void> purchasePro() async {
    final available = await isAvailable();
    if (!available) {
      throw StateError('In-app purchase is unavailable on this device.');
    }
    final product = await _ensureProductLoaded();
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

  Future<ProductDetails> _ensureProductLoaded() async {
    if (_cachedProductDetails != null) {
      return _cachedProductDetails!;
    }
    final response = await _inAppPurchase.queryProductDetails({_productId});
    if (response.notFoundIDs.contains(_productId) ||
        response.productDetails.isEmpty) {
      throw StateError('Pro product "$_productId" is not configured.');
    }
    _cachedProductDetails = response.productDetails.firstWhere(
      (item) => item.id == _productId,
      orElse: () => response.productDetails.first,
    );
    return _cachedProductDetails!;
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    var hasEntitlement = false;
    for (final purchase in updates) {
      if (purchase.productID != _productId) {
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          hasEntitlement = true;
          _entitledSeenDuringRefresh = true;
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
    } else if (updates.any((purchase) => purchase.productID == _productId)) {
      _controller.add(ProEntitlementStatus.notEntitled);
    }
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription.cancel());
    _controller.close();
  }
}
