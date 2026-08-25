import 'dart:async';
import 'dart:developer' as developer;

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
      _log('ads skipped: platform does not support mobile ads');
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
      _log('plugin unavailable: $error');
    } on PlatformException catch (error) {
      _log('init failed: $error');
    } on Object catch (error) {
      _log('init failed: $error');
    }
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    isReady.value = false;
    _log('init failed: $error');
  }

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    _nativeInitialized = true;
    isReady.value = true;
    _log('init success');
    if (kDebugMode) {
      unawaited(LevelPlay.validateIntegration());
    }
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
      _log('ATT request skipped: $error');
    }
  }

  static void _log(String message) {
    if (!kDebugMode) {
      return;
    }
    developer.log(message, name: 'OneRemote.LevelPlay');
    debugPrint('OneRemote/LevelPlay: $message');
  }
}
