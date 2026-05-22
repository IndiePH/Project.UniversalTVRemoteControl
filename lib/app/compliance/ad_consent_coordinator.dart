import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:one_remote/app/ads/ad_config.dart';

/// Runs UMP consent and iOS ATT before the Mobile Ads SDK loads ads.
class AdConsentCoordinator {
  AdConsentCoordinator._();

  static bool _canRequestAds = false;

  /// Whether personalized/non-personalized ads may be requested after consent.
  static bool get canRequestAds => _canRequestAds;

  /// Gathers regulatory consent and tracking permission, then updates [canRequestAds].
  static Future<void> prepareForAds() async {
    if (!AdConfig.supportsMobileAds) {
      _canRequestAds = false;
      return;
    }

    await _gatherUmpConsent();
    await _requestAttIfNeeded();
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
  }

  static Future<bool> isPrivacyOptionsRequired() async {
    if (!AdConfig.supportsMobileAds) {
      return false;
    }
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus()
          .timeout(const Duration(seconds: 2));
      return status == PrivacyOptionsRequirementStatus.required;
    } on Object {
      // Widget tests simulate Android but lack the Mobile Ads plugin.
      return false;
    }
  }

  static Future<void> showPrivacyOptionsForm() async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  static Future<void> _gatherUmpConsent() async {
    final params = ConsentRequestParameters(tagForUnderAgeOfConsent: false);
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          });
        } else if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (FormError error) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    return completer.future;
  }

  static Future<void> _requestAttIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    var status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      status = await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }
}
