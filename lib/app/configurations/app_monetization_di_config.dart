import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';

import 'package:one_remote/app/ads/interstitial_ad_controller.dart';
import 'package:one_remote/app/ads/interstitial_ad_policy.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/app/monetization/fake_pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/pro_receipt_validation_service.dart';
import 'package:one_remote/app/monetization/shared_prefs_pro_entitlement_cache.dart';
import 'package:one_remote/app/monetization/store_pro_entitlement_repository.dart';

final class AppMonetizationDiConfig implements IDiConfig {
  const AppMonetizationDiConfig();

  static const List<String> proProductIds = <String>[
    // Default (monthly)
    'sub-monthly-autorenew',
    // Subscription options
    'sub-weekly-autorenew',
    'sub-weekly-prepaid',
    'sub-monthly-prepaid',
    'sub-annually-autorenew',
    'sub-annually-prepaid',
    // One-time
    'purchase-lifetime',
  ];

  static const String _defaultProductId = String.fromEnvironment(
    'PRO_PRODUCT_ID',
    // Legacy: previously 'one_remote_pro'. Google Play now uses explicit
    // subscription and lifetime product IDs.
    defaultValue: 'sub-monthly-autorenew',
  );

  @override
  void configure(GetIt sl, AppEnvironment env) {
    final cache = SharedPrefsProEntitlementCache();
    final receiptValidationService = _supportsReceiptValidation &&
            Firebase.apps.isNotEmpty
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
    final interstitialPolicy = InterstitialAdPolicy(
      minSuccessfulActionsBetweenAds: 25,
      minIntervalBetweenAds: const Duration(minutes: 10),
      sessionImpressionCap: 1,
    );
    final interstitialController = InterstitialAdController(
      appEnvironment: env,
      policy: interstitialPolicy,
    );

    sl.registerSingleton<SharedPrefsProEntitlementCache>(cache);
    if (receiptValidationService != null) {
      sl.registerSingleton<ProReceiptValidationService>(receiptValidationService);
    }
    sl.registerSingleton<ProEntitlementRepository>(
      repository,
      dispose: (repo) => repo.dispose(),
    );
    sl.registerSingleton<ProEntitlementService>(
      service,
      dispose: (svc) => svc.dispose(),
    );
    sl.registerSingleton<InterstitialAdController>(
      interstitialController,
      dispose: (controller) => controller.dispose(),
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
