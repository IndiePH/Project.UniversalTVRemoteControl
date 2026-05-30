import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/configurations/app_environment.dart';

import 'package:one_remote/app/ads/ad_config.dart';

void main() {
  group('shouldUseTestAds', () {
    test('debug builds always use test ads', () {
      expect(
        AdConfig.shouldUseTestAds(
          environment: AppEnvironment.debug,
          testAdsEnabled: false,
        ),
        isTrue,
      );
    });

    test('release uses Remote Config flag when true', () {
      expect(
        AdConfig.shouldUseTestAds(
          environment: AppEnvironment.production,
          testAdsEnabled: true,
        ),
        isTrue,
      );
    });

    test('release uses live ads when Remote Config flag is false', () {
      expect(
        AdConfig.shouldUseTestAds(
          environment: AppEnvironment.production,
          testAdsEnabled: false,
        ),
        isFalse,
      );
    });
  });

  group('AdMob app id constants', () {
    test('Google test app ids use the sample publisher account', () {
      expect(
        AdConfig.googleTestAndroidAppId,
        'ca-app-pub-3940256099942544~3347511713',
      );
      expect(
        AdConfig.googleTestIosAppId,
        'ca-app-pub-3940256099942544~1458002511',
      );
    });

    test('production app ids use the OneRemote publisher account', () {
      expect(
        AdConfig.productionAndroidAppId,
        'ca-app-pub-4297882562709937~9516353394',
      );
      expect(
        AdConfig.productionIosAppId,
        'ca-app-pub-4297882562709937~9714141433',
      );
    });
  });
}
