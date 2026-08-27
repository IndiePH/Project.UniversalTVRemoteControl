import 'package:flutter/widgets.dart';
import 'package:one_remote/app/ads/ad_config.dart';
import 'package:one_remote/app/ads/bottom_banner_ad.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

/// Resolves where and whether the bottom banner ad should be shown.
class BottomBannerAdPlacement {
  const BottomBannerAdPlacement._();

  static Widget? buildOverlay({required bool showAds, required bool sdkReady}) {
    if (!showAds || !sdkReady || !AdConfig.supportsMobileAds) {
      return null;
    }

    final adSize = LevelPlayAdSize.BANNER;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: adSize.width.toDouble(),
            height: adSize.height.toDouble(),
            child: BottomBannerAd(adUnitId: AdConfig.bannerAdUnitId),
          ),
        ),
      ),
    );
  }
}
