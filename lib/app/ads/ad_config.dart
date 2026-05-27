import 'package:flutter/foundation.dart';
import 'package:one_remote/app/configurations/app_environment.dart';

class AdConfig {
  const AdConfig._();

  static bool get supportsMobileAds {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  static String? bannerAdUnitId(AppEnvironment environment) {
    if (!supportsMobileAds) {
      return null;
    }

    final isProduction = environment == AppEnvironment.production;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        isProduction
            ? const String.fromEnvironment(
                'ADMOB_BANNER_ANDROID',
                defaultValue: _productionAndroidBannerAdUnitId,
              )
            : _androidTestBannerAdUnitId,
      TargetPlatform.iOS =>
        isProduction
            ? const String.fromEnvironment(
                'ADMOB_BANNER_IOS',
                defaultValue: _iosTestBannerAdUnitId,
              )
            : _iosTestBannerAdUnitId,
      _ => null,
    };
  }

  static String? interstitialAdUnitId(AppEnvironment environment) {
    if (!supportsMobileAds) {
      return null;
    }

    final isProduction = environment == AppEnvironment.production;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        isProduction
            ? const String.fromEnvironment(
                'ADMOB_INTERSTITIAL_ANDROID',
                defaultValue: _productionAndroidInterstitialAdUnitId,
              )
            : _androidTestInterstitialAdUnitId,
      TargetPlatform.iOS =>
        isProduction
            ? const String.fromEnvironment(
                'ADMOB_INTERSTITIAL_IOS',
                defaultValue: _iosTestInterstitialAdUnitId,
              )
            : _iosTestInterstitialAdUnitId,
      _ => null,
    };
  }

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
