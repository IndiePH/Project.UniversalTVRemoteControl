import 'package:flutter/foundation.dart';
import 'package:one_remote/app/configurations/app_environment.dart';

class AdConfig {
  const AdConfig._();

  /// Google sample AdMob app IDs (reference only — not used in platform manifests).
  static const String googleTestAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String googleTestIosAppId =
      'ca-app-pub-3940256099942544~1458002511';

  /// OneRemote production AdMob app IDs — set at build time in AndroidManifest /
  /// Info.plist. Runtime test vs live switching uses ad unit IDs via
  /// [shouldUseTestAds] and Remote Config `test_ads_enabled`.
  static const String productionAndroidAppId =
      'ca-app-pub-4297882562709937~9516353394';
  static const String productionIosAppId =
      'ca-app-pub-4297882562709937~9714141433';

  static const String _productionIosBannerAdUnitId =
      'ca-app-pub-4297882562709937/4088764292';
  static const String _productionIosInterstitialAdUnitId =
      'ca-app-pub-4297882562709937/8401059763';

  static bool get supportsMobileAds {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  static bool shouldUseTestAds({
    required AppEnvironment environment,
    required bool testAdsEnabled,
  }) {
    if (environment == AppEnvironment.debug) {
      return true;
    }
    return testAdsEnabled;
  }

  static String? bannerAdUnitId({
    required AppEnvironment environment,
    required bool testAdsEnabled,
  }) {
    if (!supportsMobileAds) {
      return null;
    }

    final useTestAds = shouldUseTestAds(
      environment: environment,
      testAdsEnabled: testAdsEnabled,
    );
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => useTestAds
          ? _androidTestBannerAdUnitId
          : _liveAndroidBannerAdUnitId(),
      TargetPlatform.iOS =>
        useTestAds ? _iosTestBannerAdUnitId : _liveIosBannerAdUnitId(),
      _ => null,
    };
  }

  static String? interstitialAdUnitId({
    required AppEnvironment environment,
    required bool testAdsEnabled,
  }) {
    if (!supportsMobileAds) {
      return null;
    }

    final useTestAds = shouldUseTestAds(
      environment: environment,
      testAdsEnabled: testAdsEnabled,
    );
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => useTestAds
          ? _androidTestInterstitialAdUnitId
          : _liveAndroidInterstitialAdUnitId(),
      TargetPlatform.iOS => useTestAds
          ? _iosTestInterstitialAdUnitId
          : _liveIosInterstitialAdUnitId(),
      _ => null,
    };
  }

  static String _liveAndroidBannerAdUnitId() => const String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: _productionAndroidBannerAdUnitId,
  );

  static String _liveIosBannerAdUnitId() => const String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: _productionIosBannerAdUnitId,
  );

  static String _liveAndroidInterstitialAdUnitId() =>
      const String.fromEnvironment(
        'ADMOB_INTERSTITIAL_ANDROID',
        defaultValue: _productionAndroidInterstitialAdUnitId,
      );

  static String _liveIosInterstitialAdUnitId() => const String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: _productionIosInterstitialAdUnitId,
  );

  static const String _productionAndroidBannerAdUnitId =
      'ca-app-pub-4297882562709937/6229056524';
  static const String _productionAndroidInterstitialAdUnitId =
      'ca-app-pub-4297882562709937/6720011119';

  static const String _androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _androidTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';
}
