import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'package:one_remote/app/ads/ad_config.dart';

/// Initializes Unity LevelPlay and exposes when banners may be requested.
final class LevelPlayAdsService implements LevelPlayInitListener {
  LevelPlayAdsService();

  static bool _nativeInitialized = false;

  final ValueNotifier<bool> isReady = ValueNotifier(false);

  Future<void> initialize() async {
    if (!AdConfig.supportsMobileAds) {
      isReady.value = false;
      return;
    }
    if (_nativeInitialized) {
      isReady.value = true;
      return;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _requestAttIfNeeded();
      }
      if (kDebugMode) {
        await LevelPlay.setAdaptersDebug(true);
      }
      final initRequest = LevelPlayInitRequest.builder(AdConfig.appKey).build();
      await LevelPlay.init(initRequest: initRequest, initListener: this);
    } on MissingPluginException catch (error) {
      debugPrint('LevelPlay plugin unavailable: $error');
    } on PlatformException catch (error) {
      debugPrint('LevelPlay init failed: $error');
    } on Object catch (error) {
      debugPrint('LevelPlay init failed: $error');
    }
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    isReady.value = false;
    debugPrint('LevelPlay init failed: $error');
  }

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    _nativeInitialized = true;
    isReady.value = true;
  }

  void dispose() {
    isReady.dispose();
  }

  static Future<void> _requestAttIfNeeded() async {
    try {
      final status = await ATTrackingManager.getTrackingAuthorizationStatus();
      if (status == ATTStatus.NotDetermined) {
        await ATTrackingManager.requestTrackingAuthorization();
      }
    } on Object catch (error) {
      debugPrint('LevelPlay ATT request skipped: $error');
    }
  }
}
