import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/ads/ad_remote_config_service.dart';
import 'package:one_remote/app/ads/interstitial_ad_controller.dart';
import 'package:one_remote/app/ads/interstitial_ad_policy.dart';
import 'package:one_remote/app/configurations/app_environment.dart';

void main() {
  test('presentation block prevents nested acquire and release', () {
    final controller = InterstitialAdController(
      appEnvironment: AppEnvironment.debug,
      adRemoteConfig: AdRemoteConfigService(),
      policy: InterstitialAdPolicy(
        minSuccessfulActionsBetweenAds: 1,
        minIntervalBetweenAds: Duration.zero,
        sessionImpressionCap: 2,
      ),
    );

    expect(controller.isPresentationBlocked, isFalse);

    controller.acquirePresentationBlock();
    expect(controller.isPresentationBlocked, isTrue);

    controller.acquirePresentationBlock();
    expect(controller.isPresentationBlocked, isTrue);

    controller.releasePresentationBlock();
    expect(controller.isPresentationBlocked, isTrue);

    controller.releasePresentationBlock();
    expect(controller.isPresentationBlocked, isFalse);

    controller.releasePresentationBlock();
    expect(controller.isPresentationBlocked, isFalse);
  });
}
