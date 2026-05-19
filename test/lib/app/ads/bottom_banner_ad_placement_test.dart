import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/ads/bottom_banner_ad_placement.dart';
import 'package:one_remote/app/configurations/app_environment.dart';

void main() {
  test('does not build overlay when ads are disabled by Pro', () {
    final overlay = BottomBannerAdPlacement.buildOverlay(
      appEnvironment: AppEnvironment.production,
      showAds: false,
    );

    expect(overlay, isNull);
  });
}
