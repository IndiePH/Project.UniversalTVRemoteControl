import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/ads/ad_config.dart';

void main() {
  test('exposes the LevelPlay app key and banner unit', () {
    expect(AdConfig.appKey, '27c78d0ad');
    expect(AdConfig.bannerAdUnitId, '20azo5e9eecpv182');
  });
}
