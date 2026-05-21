import 'package:shared_preferences/shared_preferences.dart';

import 'package:one_remote/app/monetization/pro_entitlement_status.dart';

/// Non-authoritative cache used for UX hints while store verification runs.
final class SharedPrefsProEntitlementCache {
  static const String _entitledKey = 'pro.entitled';
  static const String _verifiedAtEpochMsKey = 'pro.verified_at_epoch_ms';
  static const String _debugOverrideKey = 'pro.debug_entitlement_override';

  Future<void> writeStatus(ProEntitlementStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    switch (status) {
      case ProEntitlementStatus.entitled:
        await prefs.setBool(_entitledKey, true);
        await prefs.setInt(
          _verifiedAtEpochMsKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      case ProEntitlementStatus.notEntitled:
        await prefs.setBool(_entitledKey, false);
        await prefs.setInt(
          _verifiedAtEpochMsKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      case ProEntitlementStatus.unknown:
        // Keep last resolved status for UI copy; unknown is transient.
        break;
    }
  }

  Future<ProEntitlementStatus?> readLastKnownStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final entitled = prefs.getBool(_entitledKey);
    if (entitled == null) {
      return null;
    }
    return entitled
        ? ProEntitlementStatus.entitled
        : ProEntitlementStatus.notEntitled;
  }

  Future<DateTime?> readLastVerifiedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_verifiedAtEpochMsKey);
    if (value == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<bool> readDebugEntitlementOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_debugOverrideKey) ?? false;
  }

  Future<void> writeDebugEntitlementOverride(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      await prefs.setBool(_debugOverrideKey, true);
    } else {
      await prefs.remove(_debugOverrideKey);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_entitledKey);
    await prefs.remove(_verifiedAtEpochMsKey);
    await prefs.remove(_debugOverrideKey);
  }
}
