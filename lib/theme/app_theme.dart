import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared semantic colors used by the OneRemote UI.
final class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.remoteSurface,
    required this.remoteRaisedSurface,
    required this.remoteOutline,
    required this.remoteGlyphOnRemote,
    required this.remotePowerFill,
    required this.remoteGlyphOnPower,
    required this.remoteActionSuccessFill,
    required this.remoteActionSuccessOnFill,
    required this.layoutEditorDropValid,
    required this.layoutEditorDropInvalid,
    required this.pairingModalBarrier,
    required this.pairingBusyOnCard,
    required this.remoteDisabledControlTint,
    required this.pairingHintGridTint,
  });

  final Color remoteSurface;
  final Color remoteRaisedSurface;
  final Color remoteOutline;

  /// Icons and text drawn on [remoteSurface] / [remoteRaisedSurface] (e.g. play/pause, d-pad).
  final Color remoteGlyphOnRemote;

  /// Power control fill (distinct from neutral remote tiles).
  final Color remotePowerFill;

  /// Icon/label on top of [remotePowerFill].
  final Color remoteGlyphOnPower;

  /// Accent when a “connected” shortcut applies (e.g. pair control while a device is active).
  final Color remoteActionSuccessFill;

  /// Foreground on [remoteActionSuccessFill].
  final Color remoteActionSuccessOnFill;

  /// Layout editor: drop target outline when the resolver accepts placement.
  final Color layoutEditorDropValid;

  /// Layout editor: drop target outline when placement is rejected.
  final Color layoutEditorDropInvalid;

  /// Dimming behind modal-style overlays (e.g. pairing busy).
  final Color pairingModalBarrier;

  /// Text / progress on the pairing busy card ([remoteRaisedSurface] background).
  final Color pairingBusyOnCard;

  /// Tint used to indicate remote controls are disabled.
  final Color remoteDisabledControlTint;

  /// Tint applied to remote grid while pairing hint is active.
  final Color pairingHintGridTint;

  @override
  AppColors copyWith({
    Color? remoteSurface,
    Color? remoteRaisedSurface,
    Color? remoteOutline,
    Color? remoteGlyphOnRemote,
    Color? remotePowerFill,
    Color? remoteGlyphOnPower,
    Color? remoteActionSuccessFill,
    Color? remoteActionSuccessOnFill,
    Color? layoutEditorDropValid,
    Color? layoutEditorDropInvalid,
    Color? pairingModalBarrier,
    Color? pairingBusyOnCard,
    Color? remoteDisabledControlTint,
    Color? pairingHintGridTint,
  }) {
    return AppColors(
      remoteSurface: remoteSurface ?? this.remoteSurface,
      remoteRaisedSurface: remoteRaisedSurface ?? this.remoteRaisedSurface,
      remoteOutline: remoteOutline ?? this.remoteOutline,
      remoteGlyphOnRemote: remoteGlyphOnRemote ?? this.remoteGlyphOnRemote,
      remotePowerFill: remotePowerFill ?? this.remotePowerFill,
      remoteGlyphOnPower: remoteGlyphOnPower ?? this.remoteGlyphOnPower,
      remoteActionSuccessFill:
          remoteActionSuccessFill ?? this.remoteActionSuccessFill,
      remoteActionSuccessOnFill:
          remoteActionSuccessOnFill ?? this.remoteActionSuccessOnFill,
      layoutEditorDropValid:
          layoutEditorDropValid ?? this.layoutEditorDropValid,
      layoutEditorDropInvalid:
          layoutEditorDropInvalid ?? this.layoutEditorDropInvalid,
      pairingModalBarrier: pairingModalBarrier ?? this.pairingModalBarrier,
      pairingBusyOnCard: pairingBusyOnCard ?? this.pairingBusyOnCard,
      remoteDisabledControlTint:
          remoteDisabledControlTint ?? this.remoteDisabledControlTint,
      pairingHintGridTint: pairingHintGridTint ?? this.pairingHintGridTint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      remoteSurface:
          Color.lerp(remoteSurface, other.remoteSurface, t) ?? remoteSurface,
      remoteRaisedSurface:
          Color.lerp(remoteRaisedSurface, other.remoteRaisedSurface, t) ??
          remoteRaisedSurface,
      remoteOutline:
          Color.lerp(remoteOutline, other.remoteOutline, t) ?? remoteOutline,
      remoteGlyphOnRemote:
          Color.lerp(remoteGlyphOnRemote, other.remoteGlyphOnRemote, t) ??
          remoteGlyphOnRemote,
      remotePowerFill:
          Color.lerp(remotePowerFill, other.remotePowerFill, t) ??
          remotePowerFill,
      remoteGlyphOnPower:
          Color.lerp(remoteGlyphOnPower, other.remoteGlyphOnPower, t) ??
          remoteGlyphOnPower,
      remoteActionSuccessFill:
          Color.lerp(
            remoteActionSuccessFill,
            other.remoteActionSuccessFill,
            t,
          ) ??
          remoteActionSuccessFill,
      remoteActionSuccessOnFill:
          Color.lerp(
            remoteActionSuccessOnFill,
            other.remoteActionSuccessOnFill,
            t,
          ) ??
          remoteActionSuccessOnFill,
      layoutEditorDropValid:
          Color.lerp(layoutEditorDropValid, other.layoutEditorDropValid, t) ??
          layoutEditorDropValid,
      layoutEditorDropInvalid:
          Color.lerp(
            layoutEditorDropInvalid,
            other.layoutEditorDropInvalid,
            t,
          ) ??
          layoutEditorDropInvalid,
      pairingModalBarrier:
          Color.lerp(pairingModalBarrier, other.pairingModalBarrier, t) ??
          pairingModalBarrier,
      pairingBusyOnCard:
          Color.lerp(pairingBusyOnCard, other.pairingBusyOnCard, t) ??
          pairingBusyOnCard,
      remoteDisabledControlTint:
          Color.lerp(
            remoteDisabledControlTint,
            other.remoteDisabledControlTint,
            t,
          ) ??
          remoteDisabledControlTint,
      pairingHintGridTint:
          Color.lerp(pairingHintGridTint, other.pairingHintGridTint, t) ??
          pairingHintGridTint,
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
          remoteOutline: Color.fromARGB(15, 216, 221, 230),
          // Dark glyphs on light remote surfaces (play/pause, d-pad, layout previews).
          remoteGlyphOnRemote: Color(0xFF1A1D24),
          remotePowerFill: Color(0xFFE53935),
          remoteGlyphOnPower: Color(0xFFFFFFFF),
          remoteActionSuccessFill: Color(0xFF43A047),
          remoteActionSuccessOnFill: Color(0xFFFFFFFF),
          layoutEditorDropValid: Color(0xFF4CAF50),
          layoutEditorDropInvalid: Color(0xFFFF9800),
          pairingModalBarrier: Color(0x8A000000),
          pairingBusyOnCard: Color(0xFF1A1D24),
          remoteDisabledControlTint: Color(0xFF78909C),
          pairingHintGridTint: Color(0xFF64B5F6),
        );
      case Brightness.dark:
        return const AppColors(
          remoteSurface: Color(0xFF111317),
          remoteRaisedSurface: Color(0xFF1B1D22),
          remoteOutline: Color(0xFF2D3138),
          remoteGlyphOnRemote: Color(0xFFFFFFFF),
          remotePowerFill: Color(0xFFE53935),
          remoteGlyphOnPower: Color(0xFFFFFFFF),
          remoteActionSuccessFill: Color(0xFF43A047),
          remoteActionSuccessOnFill: Color(0xFFFFFFFF),
          layoutEditorDropValid: Color(0xFF4CAF50),
          layoutEditorDropInvalid: Color(0xFFFF9800),
          pairingModalBarrier: Color(0x8A000000),
          pairingBusyOnCard: Color(0xFFFFFFFF),
          remoteDisabledControlTint: Color(0xFF607D8B),
          pairingHintGridTint: Color(0xFF4FC3F7),
        );
    }
  }

  static AppColors colorsOf(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        createAppColors(brightness: theme.brightness);
  }

  static ThemeData lightTheme() => _themeFor(Brightness.light);

  static ThemeData darkTheme() => _themeFor(Brightness.dark);

  static ThemeData _themeFor(Brightness brightness) {
    const seed = Color(0xFF3D5AFE);
    final appColors = createAppColors(brightness: brightness);
    final scaffoldBackgroundColor = switch (brightness) {
      Brightness.light => const Color(0xFFE8EAEF),
      Brightness.dark => const Color(0xFF111216),
    };
    final statusBarIconBrightness = switch (brightness) {
      Brightness.light => Brightness.dark,
      Brightness.dark => Brightness.light,
    };
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness: statusBarIconBrightness,
          systemNavigationBarIconBrightness: statusBarIconBrightness,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[appColors],
    );
  }
}
