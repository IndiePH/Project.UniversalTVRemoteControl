import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_button_metrics.dart';
import 'package:one_remote/theme/app_theme.dart';

/// Circular icon-or-label button used inside the remote grid.
///
/// Sizing comes from `remote_layout_button_metrics.dart` so the live remote
/// and the layout editor preview render the button identically.
class RemoteIconCircleButton extends StatelessWidget {
  const RemoteIconCircleButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.label,
    this.isPower = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData? icon;
  final String? label;
  /// When null, the button is shown in a disabled (non-interactive) state.
  final VoidCallback? onPressed;
  final bool isPower;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    assert(
      icon != null || label != null,
      'Either icon or label must be provided.',
    );
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = AppTheme.colorsOf(context);
    final background =
        backgroundColor ??
        (isPower ? appColors.remotePowerFill : appColors.remoteSurface);
    final iconColor = foregroundColor ??
        (isPower ? appColors.remoteGlyphOnPower : colorScheme.onSurface);
    final child = icon != null
        ? Icon(icon, color: iconColor, size: kRemoteIconCircleButtonIconSize)
        : Text(
            label!,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          );

    return Container(
      width: kRemoteIconCircleButtonSize,
      height: kRemoteIconCircleButtonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(
          color: appColors.remoteOutline,
          width: kRemoteIconCircleButtonBorderWidth,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: child,
      ),
    );
  }
}
