import 'package:flutter/material.dart';
import 'package:one_remote/src/theme/app_theme.dart';

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
        (isPower ? Colors.red.shade600 : appColors.remoteSurface);
    final iconColor =
        foregroundColor ?? (isPower ? Colors.white : colorScheme.onSurface);
    final child = icon != null
        ? Icon(icon, color: iconColor, size: 34)
        : Text(
            label!,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          );

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(color: appColors.remoteOutline, width: 1.2),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: child,
      ),
    );
  }
}
