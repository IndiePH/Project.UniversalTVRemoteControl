import 'package:flutter/widgets.dart';
import 'package:one_remote/app/ads/ad_config.dart';
import 'package:one_remote/app/ads/bottom_banner_ad.dart';
import 'package:one_remote/app/compliance/ad_consent_coordinator.dart';
import 'package:one_remote/app/configurations/app_environment.dart';

/// Resolves where and whether the bottom banner ad should be shown.
class BottomBannerAdPlacement {
  const BottomBannerAdPlacement._();

  static Widget? buildOverlay({
    required AppEnvironment appEnvironment,
    required bool showAds,
  }) {
    if (!showAds || !AdConsentCoordinator.canRequestAds) {
      return null;
    }
    final adUnitId = AdConfig.bannerAdUnitId(appEnvironment);
    if (adUnitId == null) {
      return null;
    }

    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: BottomBannerAd(adUnitId: adUnitId),
      ),
    );
  }
}
