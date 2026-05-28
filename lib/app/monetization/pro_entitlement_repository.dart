import 'dart:async';

import 'package:one_remote/app/monetization/pro_entitlement_status.dart';

/// Contract for loading and updating Pro entitlement from the app store.
abstract interface class ProEntitlementRepository {
  Stream<ProEntitlementStatus> get entitlementStream;

  Future<bool> isAvailable();

  Future<void> refreshEntitlement();

  Future<void> purchasePro({String? productId});

  Future<void> restorePurchases();

  void dispose();
}
