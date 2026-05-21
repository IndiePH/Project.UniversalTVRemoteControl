import 'package:flutter/foundation.dart';
import 'package:one_remote/app/theme/app_theme_preference.dart';
import 'package:one_remote/app/theme/app_theme_settings.dart';

/// Holds the active [AppThemePreference] and persists updates.
final class AppThemeController {
  AppThemeController(AppThemePreference initial)
      : preferenceNotifier = ValueNotifier(initial);

  final ValueNotifier<AppThemePreference> preferenceNotifier;

  AppThemePreference get preference => preferenceNotifier.value;

  Future<void> setPreference(AppThemePreference value) async {
    if (preferenceNotifier.value == value) {
      return;
    }
    preferenceNotifier.value = value;
    await AppThemeSettings.write(value);
  }

  static Future<AppThemeController> load() async {
    final stored = await AppThemeSettings.read();
    return AppThemeController(stored ?? AppThemePreference.dark);
  }
}
