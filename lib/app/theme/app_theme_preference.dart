import 'package:flutter/material.dart';

/// User-selected appearance; [system] follows the device light/dark setting.
enum AppThemePreference {
  light,
  dark,
  system;

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.system => ThemeMode.system,
  };

  static AppThemePreference fromStorage(String? value) {
    return switch (value) {
      'light' => AppThemePreference.light,
      'dark' => AppThemePreference.dark,
      'system' => AppThemePreference.system,
      _ => AppThemePreference.dark,
    };
  }

  String get storageValue => switch (this) {
    AppThemePreference.light => 'light',
    AppThemePreference.dark => 'dark',
    AppThemePreference.system => 'system',
  };
}
