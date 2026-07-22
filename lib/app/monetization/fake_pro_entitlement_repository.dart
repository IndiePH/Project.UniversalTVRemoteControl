import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';

/// Fallback repository for unsupported platforms and tests.
final class FakeProEntitlementRepository implements ProEntitlementRepository {
  FakeProEntitlementRepository({
    ProEntitlementStatus initialStatus = ProEntitlementStatus.notEntitled,
    this._isAvailable = true,
  }) : _status = initialStatus;

  final StreamController<ProEntitlementStatus> _controller =
      StreamController<ProEntitlementStatus>.broadcast();
  ProEntitlementStatus _status;
  bool _isAvailable;

  @override
  Stream<ProEntitlementStatus> get entitlementStream => _controller.stream;

  @override
  String? get activeProductId => null;

  @override
  DateTime? get subscriptionExpiresAt => null;

  @override
  Future<bool> isAvailable() async => _isAvailable;

  @override
  Future<void> refreshEntitlement() async {
    _controller.add(_status);
  }

  @override
  Future<void> purchasePro({
    String? productId,
    ProductDetails? productDetails,
  }) async {
    _status = ProEntitlementStatus.entitled;
    _controller.add(_status);
  }

  @override
  Future<List<ProductDetails>> queryProProductDetails() async => const [];

  @override
  Future<void> restorePurchases() async {
    _controller.add(_status);
  }

  void setAvailability(bool value) {
    _isAvailable = value;
  }

  void setStatus(ProEntitlementStatus status) {
    _status = status;
    _controller.add(_status);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
