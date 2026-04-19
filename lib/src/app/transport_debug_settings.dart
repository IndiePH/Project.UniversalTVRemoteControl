import 'package:shared_preferences/shared_preferences.dart';

/// Persists debug transport overrides so APK builds can switch fake vs real
/// without `--dart-define` (still honored as default when no override is stored).
abstract final class TransportDebugSettings {
  static const String keyUseFakeTransports = 'debug_use_fake_transports';

  /// `null` means “no saved override — use compile-time default.”
  static Future<bool?> readUseFakeTransportsOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyUseFakeTransports);
  }

  static Future<void> writeUseFakeTransports(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyUseFakeTransports, value);
  }
}
