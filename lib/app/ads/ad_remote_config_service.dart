import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:one_remote/app/ads/ad_config.dart';

/// Resolves whether AdMob should use Google demo ad units from Firebase Remote Config.
///
/// AdMob app IDs are fixed at build time; this flag only switches banner and
/// interstitial ad unit IDs at runtime.
final class AdRemoteConfigService {
  AdRemoteConfigService({bool? testAdsEnabled})
    : _testAdsEnabled = testAdsEnabled ?? defaultTestAdsEnabled;

  static const String testAdsEnabledKey = 'test_ads_enabled';

  /// Fail-safe default: prefer test ads when Remote Config is unavailable.
  static const bool defaultTestAdsEnabled = true;

  bool _testAdsEnabled;

  bool get testAdsEnabled => _testAdsEnabled;

  /// For tests and app restart flows that should skip a network fetch.
  factory AdRemoteConfigService.withDefaults({bool testAdsEnabled = true}) {
    return AdRemoteConfigService(testAdsEnabled: testAdsEnabled);
  }

  Future<void> fetchAndActivate() async {
    if (!AdConfig.supportsMobileAds || Firebase.apps.isEmpty) {
      _testAdsEnabled = defaultTestAdsEnabled;
      return;
    }

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults({
        testAdsEnabledKey: defaultTestAdsEnabled,
      });
      await remoteConfig.fetchAndActivate();
      _testAdsEnabled = remoteConfig.getBool(testAdsEnabledKey);
    } catch (_) {
      _testAdsEnabled = defaultTestAdsEnabled;
    }
  }
}
