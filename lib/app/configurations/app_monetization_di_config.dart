import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/app/monetization/fake_pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/shared_prefs_pro_entitlement_cache.dart';
import 'package:one_remote/app/monetization/store_pro_entitlement_repository.dart';

final class AppMonetizationDiConfig implements IDiConfig {
  const AppMonetizationDiConfig();

  static const String _defaultProductId = String.fromEnvironment(
    'PRO_PRODUCT_ID',
    defaultValue: 'one_remote_pro',
  );

  @override
  void configure(GetIt sl, AppEnvironment env) {
    final cache = SharedPrefsProEntitlementCache();
    final repository = _supportsInAppPurchaseStore
        ? StoreProEntitlementRepository(productId: _defaultProductId)
        : FakeProEntitlementRepository(isAvailable: false);
    final service = ProEntitlementService(repository: repository, cache: cache);

    sl.registerSingleton<SharedPrefsProEntitlementCache>(cache);
    sl.registerSingleton<ProEntitlementRepository>(
      repository,
      dispose: (repo) => repo.dispose(),
    );
    sl.registerSingleton<ProEntitlementService>(
      service,
      dispose: (svc) => svc.dispose(),
    );
  }

  static bool get _supportsInAppPurchaseStore {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }
}
