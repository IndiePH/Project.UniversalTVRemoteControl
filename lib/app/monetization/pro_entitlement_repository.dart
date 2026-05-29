import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:one_remote/app/monetization/pro_entitlement_status.dart';

/// Contract for loading and updating Pro entitlement from the app store.
abstract interface class ProEntitlementRepository {
  Stream<ProEntitlementStatus> get entitlementStream;

  /// Last entitled product ID reported by the store, if any.
  String? get activeProductId;

  /// Subscription renewal/expiry time from the last successful validation.
  DateTime? get subscriptionExpiresAt;

  Future<bool> isAvailable();

  Future<void> refreshEntitlement();

  Future<void> purchasePro({String? productId, ProductDetails? productDetails});

  /// Loads configured Pro products from the store for the upgrade UI.
  Future<List<ProductDetails>> queryProProductDetails();

  Future<void> restorePurchases();

  void dispose();
}
