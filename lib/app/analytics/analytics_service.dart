import 'dart:ui' show Locale;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// App-level wrapper for Firebase Analytics.
///
/// Intentionally **events-only**: do not attach navigator observers or log
/// screen_view events from here.
final class AnalyticsService {
  AnalyticsService();

  String? _countryAtStartup;

  FirebaseAnalytics? _tryAnalytics() {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseAnalytics.instance;
  }

  /// Capture country once at app start so events can reuse it.
  ///
  /// This intentionally does not try to keep up with locale changes.
  void setCountryAtStartup(Locale locale) {
    _countryAtStartup = (locale.countryCode?.trim().isNotEmpty ?? false)
        ? locale.countryCode!.trim().toUpperCase()
        : 'UNKNOWN';
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
    bool includeStartupCountry = true,
  }) {
    final analytics = _tryAnalytics();
    if (analytics == null) {
      return Future.value();
    }
    final merged = <String, Object>{
      if (includeStartupCountry) 'country': _countryAtStartup ?? 'UNKNOWN',
    };
    for (final entry in parameters.entries) {
      final value = entry.value;
      if (value == null) continue;
      merged[entry.key] = value;
    }
    return analytics.logEvent(name: name, parameters: merged);
  }

  Future<void> pairingStart() => logEvent(
    'pairing_start',
    includeStartupCountry: false,
  );

  Future<void> pairingCancel() => logEvent(
    'pairing_cancel',
    includeStartupCountry: false,
  );

  Future<void> pairingSuccess({required String tvBrand}) => logEvent(
    'pairing_success',
    includeStartupCountry: false,
    parameters: {'tv_brand': tvBrand},
  );

  Future<void> proPurchaseStart() => logEvent('pro_purchase_start');

  Future<void> proRestoreStart() => logEvent('pro_restore_start');

  Future<void> proEntitlementChanged({required String status}) => logEvent(
    'pro_entitlement_changed',
    parameters: {'status': status},
  );
}

