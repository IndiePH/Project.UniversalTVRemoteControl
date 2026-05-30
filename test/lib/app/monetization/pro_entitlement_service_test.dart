import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/monetization/restore_purchases_outcome.dart';
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
    'applyLastKnownStatusFromCache restores entitled before store refresh',
    () async {
      final cache = SharedPrefsProEntitlementCache();
      await cache.writeStatus(ProEntitlementStatus.entitled);
      final repository = _StubProEntitlementRepository(
        isAvailableValue: true,
        onRefresh: () async {},
      );
      final service = ProEntitlementService(
        repository: repository,
        cache: cache,
      );

      await service.applyLastKnownStatusFromCache();

      expect(service.statusNotifier.value, ProEntitlementStatus.entitled);
      await service.dispose();
    },
  );

  test(
    'applyLastKnownStatusFromCache marks unknown when subscription expired',
    () async {
      final cache = SharedPrefsProEntitlementCache();
      await cache.writeStatus(ProEntitlementStatus.entitled);
      await cache.writeActiveProductId('sub_weekly');
      await cache.writeSubscriptionExpiresAt(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final repository = _StubProEntitlementRepository(
        isAvailableValue: true,
        onRefresh: () async {},
      );
      final service = ProEntitlementService(
        repository: repository,
        cache: cache,
      );

      await service.applyLastKnownStatusFromCache();

      expect(service.statusNotifier.value, ProEntitlementStatus.unknown);
      await service.dispose();
    },
  );

  test(
    'reconcileExpiredSubscriptionFromCache clears entitled subscription',
    () async {
      final cache = SharedPrefsProEntitlementCache();
      final repository = _StubProEntitlementRepository(
        isAvailableValue: true,
        onRefresh: () async {},
      );
      final service = ProEntitlementService(
        repository: repository,
        cache: cache,
      );
      service.statusNotifier.value = ProEntitlementStatus.entitled;
      service.activeProductIdNotifier.value = 'sub_weekly';
      service.subscriptionExpiresAtNotifier.value = DateTime.now().subtract(
        const Duration(minutes: 1),
      );

      final reconciled = service.reconcileExpiredSubscriptionFromCache();

      expect(reconciled, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(service.statusNotifier.value, ProEntitlementStatus.notEntitled);
      expect(service.subscriptionExpiresAtNotifier.value, isNull);
      await service.dispose();
    },
  );

  test('debug toggle pro survives refreshFromStore in debug builds', () async {
    late _StubProEntitlementRepository repository;
    repository = _StubProEntitlementRepository(
      isAvailableValue: true,
      onRefresh: () async {
        repository.emit(ProEntitlementStatus.notEntitled);
      },
    );
    final cache = SharedPrefsProEntitlementCache();
    final service = ProEntitlementService(repository: repository, cache: cache);

    await service.debugToggleEntitlement();
    expect(service.isPro, isTrue);

    await service.refreshFromStore(isDebugBuild: true);

    expect(service.isPro, isTrue);
    await service.dispose();
  });

  test('refreshFromStore clears debug pro when not in debug build', () async {
    late _StubProEntitlementRepository repository;
    repository = _StubProEntitlementRepository(
      isAvailableValue: true,
      onRefresh: () async {
        repository.emit(ProEntitlementStatus.notEntitled);
      },
    );
    final cache = SharedPrefsProEntitlementCache();
    final service = ProEntitlementService(repository: repository, cache: cache);

    await service.debugToggleEntitlement();
    await service.refreshFromStore(isDebugBuild: false);

    expect(service.isPro, isFalse);
    await service.dispose();
  });

  test(
    'restorePurchases keeps notEntitled when no restored purchase',
    () async {
      late _StubProEntitlementRepository repository;
      repository = _StubProEntitlementRepository(
        isAvailableValue: true,
        onRefresh: () async {
          repository.emit(ProEntitlementStatus.notEntitled);
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
      expect(service.statusNotifier.value, ProEntitlementStatus.notEntitled);

      final outcome = await service.restorePurchases();

      expect(outcome, RestorePurchasesOutcome.noPurchasesFound);
      expect(service.statusNotifier.value, ProEntitlementStatus.notEntitled);
      expect(service.isPro, isFalse);
      await service.dispose();
    },
  );

  test('restorePurchases reports restored when entitlement is found', () async {
    late _StubProEntitlementRepository repository;
    repository = _StubProEntitlementRepository(
      isAvailableValue: true,
      onRefresh: () async {},
      onRestore: () async {
        repository.emit(ProEntitlementStatus.entitled);
      },
    );
    final service = ProEntitlementService(
      repository: repository,
      cache: SharedPrefsProEntitlementCache(),
    );
    await service.refreshFromStore();

    final outcome = await service.restorePurchases();

    expect(outcome, RestorePurchasesOutcome.restored);
    expect(service.isPro, isTrue);
    await service.dispose();
  });

  test(
    'restorePurchases reports failed when validation fails',
    () async {
      late _StubProEntitlementRepository repository;
      repository = _StubProEntitlementRepository(
        isAvailableValue: true,
        onRefresh: () async {
          repository.emit(ProEntitlementStatus.notEntitled);
        },
        onRestore: () async {
          throw const ProRestoreValidationFailedException();
        },
      );
      final service = ProEntitlementService(
        repository: repository,
        cache: SharedPrefsProEntitlementCache(),
      );

      await service.refreshFromStore();
      final outcome = await service.restorePurchases();

      expect(outcome, RestorePurchasesOutcome.failed);
      expect(service.isPro, isFalse);
      await service.dispose();
    },
  );
}

final class _StubProEntitlementRepository implements ProEntitlementRepository {
  _StubProEntitlementRepository({
    required this._isAvailableValue,
    required this._onRefresh,
    Future<void> Function()? onPurchase,
    Future<void> Function()? onRestore,
  }) : _onPurchase = onPurchase ?? (() async {}),
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
  String? get activeProductId => null;

  @override
  DateTime? get subscriptionExpiresAt => null;

  @override
  Future<bool> isAvailable() async => _isAvailableValue;

  @override
  Future<void> purchasePro({String? productId, ProductDetails? productDetails}) =>
      _onPurchase();

  @override
  Future<List<ProductDetails>> queryProProductDetails() async => const [];

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
