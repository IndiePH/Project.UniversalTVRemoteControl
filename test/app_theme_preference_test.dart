import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/theme/app_theme_preference.dart';

void main() {
  group('AppThemePreference', () {
    test('maps to ThemeMode', () {
      expect(AppThemePreference.light.themeMode, ThemeMode.light);
      expect(AppThemePreference.dark.themeMode, ThemeMode.dark);
      expect(AppThemePreference.system.themeMode, ThemeMode.system);
    });

    test('round-trips storage values', () {
      for (final preference in AppThemePreference.values) {
        expect(
          AppThemePreference.fromStorage(preference.storageValue),
          preference,
        );
      }
    });

    test('unknown storage defaults to dark', () {
      expect(
        AppThemePreference.fromStorage('invalid'),
        AppThemePreference.dark,
      );
      expect(AppThemePreference.fromStorage(null), AppThemePreference.dark);
    });
  });
}
