import 'package:one_remote/app/theme/app_theme_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's appearance preference across launches.
abstract final class AppThemeSettings {
  static const String keyThemePreference = 'app_theme_preference';

  static Future<AppThemePreference?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyThemePreference);
    if (raw == null) {
      return null;
    }
    return AppThemePreference.fromStorage(raw);
  }

  static Future<void> write(AppThemePreference value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyThemePreference, value.storageValue);
  }
}
