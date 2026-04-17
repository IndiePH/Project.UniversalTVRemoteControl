import 'package:flutter/material.dart';

final class AppTheme {
  const AppTheme._();

  static ThemeData darkTheme() {
    const seed = Color(0xFF3D5AFE);
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF111216),
    );
  }
}
