import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:one_remote/app/ads/ad_config.dart';
import 'package:one_remote/app/ads/ad_remote_config_service.dart';
import 'package:one_remote/app/ads/interstitial_ad_policy.dart';
import 'package:one_remote/app/configurations/app_environment.dart';

/// Coordinates loading and showing interstitial ads using [InterstitialAdPolicy].
class InterstitialAdController {
  InterstitialAdController({
    required this._appEnvironment,
    required this._adRemoteConfig,
    required this._policy,
  });

  final AppEnvironment _appEnvironment;
  final AdRemoteConfigService _adRemoteConfig;
  final InterstitialAdPolicy _policy;

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  bool _isShowing = false;

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  void recordSuccessfulAction({
    required bool showAds,
    required bool canRequestAds,
  }) {
    _policy.recordSuccessfulAction();
    if (showAds && canRequestAds) {
      _preloadIfNeeded();
    }
  }

  void warmUp({required bool showAds, required bool canRequestAds}) {
    if (showAds && canRequestAds) {
      _preloadIfNeeded();
      return;
    }
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  Future<void> maybeShow({
    required BuildContext context,
    required bool showAds,
    required bool canRequestAds,
    required bool isLayoutEditMode,
    required bool isModalOpen,
  }) async {
    if (_isShowing) {
      return;
    }
    if (!_policy.canShow(
      showAds: showAds,
      canRequestAds: canRequestAds,
      isLayoutEditMode: isLayoutEditMode,
      isModalOpen: isModalOpen,
    )) {
      return;
    }

    await _showLoadedAd(context);
  }

  /// Shows a loaded interstitial immediately, bypassing engagement policy gates.
  ///
  /// Intended for debug/manual ad verification only.
  Future<void> showForTesting({
    required BuildContext context,
    required bool showAds,
    required bool canRequestAds,
  }) async {
    if (_isShowing || !showAds || !canRequestAds) {
      return;
    }
    await _showLoadedAd(context, recordPolicyOnShow: false);
  }

  Future<void> _showLoadedAd(
    BuildContext context, {
    bool recordPolicyOnShow = true,
  }) async {
    final ad = _interstitialAd;
    if (ad == null) {
      _preloadIfNeeded();
      return;
    }

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return;
    }

    _interstitialAd = null;
    _isShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        if (recordPolicyOnShow) {
          _policy.recordShown();
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowing = false;
        ad.dispose();
        _preloadIfNeeded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _isShowing = false;
        ad.dispose();
        _preloadIfNeeded();
      },
    );
    await ad.show();
  }

  void _preloadIfNeeded() {
    if (_isLoading || _interstitialAd != null) {
      return;
    }
    final adUnitId = AdConfig.interstitialAdUnitId(
      environment: _appEnvironment,
      testAdsEnabled: _adRemoteConfig.testAdsEnabled,
    );
    if (adUnitId == null) {
      return;
    }

    _isLoading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _isLoading = false;
        },
      ),
    );
  }
}
