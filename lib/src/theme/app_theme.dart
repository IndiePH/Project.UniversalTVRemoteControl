import 'package:flutter/material.dart';

/// Shared semantic colors used by the OneRemote UI.
final class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.remoteSurface,
    required this.remoteRaisedSurface,
    required this.remoteOutline,
  });

  final Color remoteSurface;
  final Color remoteRaisedSurface;
  final Color remoteOutline;

  @override
  AppColors copyWith({
    Color? remoteSurface,
    Color? remoteRaisedSurface,
    Color? remoteOutline,
  }) {
    return AppColors(
      remoteSurface: remoteSurface ?? this.remoteSurface,
      remoteRaisedSurface: remoteRaisedSurface ?? this.remoteRaisedSurface,
      remoteOutline: remoteOutline ?? this.remoteOutline,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      remoteSurface: Color.lerp(remoteSurface, other.remoteSurface, t) ?? remoteSurface,
      remoteRaisedSurface:
          Color.lerp(remoteRaisedSurface, other.remoteRaisedSurface, t) ??
          remoteRaisedSurface,
      remoteOutline: Color.lerp(remoteOutline, other.remoteOutline, t) ?? remoteOutline,
    );
  }
}

/// Builds the app theme and exposes semantic color tokens.
final class AppTheme {
  const AppTheme._();

  static AppColors createAppColors({required Brightness brightness}) {
    switch (brightness) {
      case Brightness.light:
        return const AppColors(
          remoteSurface: Color(0xFFF2F4F8),
          remoteRaisedSurface: Colors.white,
          remoteOutline: Color(0xFFD8DDE6),
        );
      case Brightness.dark:
        return const AppColors(
          remoteSurface: Color(0xFF111317),
          remoteRaisedSurface: Color(0xFF1B1D22),
          remoteOutline: Color(0xFF2D3138),
        );
    }
  }

  static AppColors colorsOf(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        createAppColors(brightness: theme.brightness);
  }

  static ThemeData darkTheme() {
    const seed = Color(0xFF3D5AFE);
    final appColors = createAppColors(brightness: Brightness.dark);
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF111216),
      extensions: <ThemeExtension<dynamic>>[appColors],
    );
  }
}
