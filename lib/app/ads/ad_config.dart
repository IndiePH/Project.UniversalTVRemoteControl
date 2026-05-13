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
      TargetPlatform.android => isProduction
          ? const String.fromEnvironment(
              'ADMOB_BANNER_ANDROID',
              defaultValue: _androidTestBannerAdUnitId,
            )
          : _androidTestBannerAdUnitId,
      TargetPlatform.iOS => isProduction
          ? const String.fromEnvironment(
              'ADMOB_BANNER_IOS',
              defaultValue: _iosTestBannerAdUnitId,
            )
          : _iosTestBannerAdUnitId,
      _ => null,
    };
  }

  static const String _androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
}
