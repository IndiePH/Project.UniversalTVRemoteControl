import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';

import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/app/monetization/fake_pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/pro_receipt_validation_service.dart';
import 'package:one_remote/app/monetization/pro_product_ids.dart';
import 'package:one_remote/app/monetization/shared_prefs_pro_entitlement_cache.dart';
import 'package:one_remote/app/monetization/store_pro_entitlement_repository.dart';
import 'package:one_remote/app/ads/level_play_ads_service.dart';

final class AppMonetizationDiConfig implements IDiConfig {
  const AppMonetizationDiConfig();

  static const String lifetimeProductId = ProProductIds.lifetime;

  static const List<String> proProductIds = ProProductIds.catalog;

  static const String _defaultProductId = String.fromEnvironment(
    'PRO_PRODUCT_ID',
    // Legacy: previously 'one_remote_pro'. Google Play uses explicit product IDs
    // for subscriptions and one-time purchases.
    defaultValue: 'sub_monthly',
  );

  @override
  void configure(GetIt sl, AppEnvironment env) {
    final cache = SharedPrefsProEntitlementCache();
    final receiptValidationService =
        _supportsReceiptValidation && Firebase.apps.isNotEmpty
        ? ProReceiptValidationService()
        : null;
    final repository = _supportsInAppPurchaseStore
        ? StoreProEntitlementRepository(
            defaultProductId: _defaultProductId,
            productIds: proProductIds,
            receiptValidationService: receiptValidationService,
          )
        : FakeProEntitlementRepository(isAvailable: false);
    final service = ProEntitlementService(repository: repository, cache: cache);

    sl.registerSingleton<SharedPrefsProEntitlementCache>(cache);
    if (receiptValidationService != null) {
      sl.registerSingleton<ProReceiptValidationService>(
        receiptValidationService,
      );
    }
    sl.registerSingleton<ProEntitlementRepository>(
      repository,
      dispose: (repo) => repo.dispose(),
    );
    sl.registerSingleton<ProEntitlementService>(
      service,
      dispose: (svc) => svc.dispose(),
    );
    sl.registerSingleton<LevelPlayAdsService>(
      LevelPlayAdsService(),
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

  static bool get _supportsReceiptValidation {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }
}
