import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/ads/bottom_banner_ad_placement.dart';

void main() {
  test('does not build overlay when ads are disabled by Pro', () {
    final overlay = BottomBannerAdPlacement.buildOverlay(
      showAds: false,
      sdkReady: true,
    );

    expect(overlay, isNull);
  });

  test('does not build overlay before LevelPlay is ready', () {
    final overlay = BottomBannerAdPlacement.buildOverlay(
      showAds: true,
      sdkReady: false,
    );

    expect(overlay, isNull);
  });
}
