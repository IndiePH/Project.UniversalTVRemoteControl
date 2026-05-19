import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/monetization/shared_prefs_pro_entitlement_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('refreshFromStore sets notEntitled when store unavailable', () async {
    final repository = _StubProEntitlementRepository(
      isAvailableValue: false,
      onRefresh: () async {},
    );
    final service = ProEntitlementService(
      repository: repository,
      cache: SharedPrefsProEntitlementCache(),
    );

    await service.refreshFromStore();

    expect(service.statusNotifier.value, ProEntitlementStatus.notEntitled);
    expect(service.storeAvailableNotifier.value, isFalse);
    await service.dispose();
  });

  test('refreshFromStore applies entitled status from repository', () async {
    late _StubProEntitlementRepository repository;
    repository = _StubProEntitlementRepository(
      isAvailableValue: true,
      onRefresh: () async {
        repository.emit(ProEntitlementStatus.entitled);
      },
    );
    final service = ProEntitlementService(
      repository: repository,
      cache: SharedPrefsProEntitlementCache(),
    );

    await service.refreshFromStore();

    expect(service.statusNotifier.value, ProEntitlementStatus.entitled);
    expect(service.isPro, isTrue);
    await service.dispose();
  });

  test(
    'restorePurchases keeps notEntitled when no restored purchase',
    () async {
      late _StubProEntitlementRepository repository;
      repository = _StubProEntitlementRepository(
        isAvailableValue: true,
        onRefresh: () async {
          repository.emit(ProEntitlementStatus.entitled);
        },
        onRestore: () async {
          repository.emit(ProEntitlementStatus.notEntitled);
        },
      );
      final service = ProEntitlementService(
        repository: repository,
        cache: SharedPrefsProEntitlementCache(),
      );

      await service.refreshFromStore();
      expect(service.statusNotifier.value, ProEntitlementStatus.entitled);

      await service.restorePurchases();

      expect(service.statusNotifier.value, ProEntitlementStatus.notEntitled);
      expect(service.isPro, isFalse);
      await service.dispose();
    },
  );
}

final class _StubProEntitlementRepository implements ProEntitlementRepository {
  _StubProEntitlementRepository({
    required bool isAvailableValue,
    required Future<void> Function() onRefresh,
    Future<void> Function()? onPurchase,
    Future<void> Function()? onRestore,
  }) : _isAvailableValue = isAvailableValue,
       _onRefresh = onRefresh,
       _onPurchase = onPurchase ?? (() async {}),
       _onRestore = onRestore ?? (() async {});

  final bool _isAvailableValue;
  final Future<void> Function() _onRefresh;
  final Future<void> Function() _onPurchase;
  final Future<void> Function() _onRestore;

  final StreamController<ProEntitlementStatus> _controller =
      StreamController<ProEntitlementStatus>.broadcast();

  @override
  Stream<ProEntitlementStatus> get entitlementStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => _isAvailableValue;

  @override
  Future<void> purchasePro() => _onPurchase();

  @override
  Future<void> refreshEntitlement() => _onRefresh();

  @override
  Future<void> restorePurchases() => _onRestore();

  void emit(ProEntitlementStatus status) {
    _controller.add(status);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
