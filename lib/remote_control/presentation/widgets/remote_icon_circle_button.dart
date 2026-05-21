import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_command_haptic_feedback.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_press_feedback.dart';
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
    this.imageAsset,
    this.imageIconSize,
    this.brandColor,
    this.label,
    this.isPower = false,
    this.backgroundColor,
    this.foregroundColor,
    this.interactionCommand,
    this.onPressHaptic,
  });

  final IconData? icon;
  final String? imageAsset;
  /// When set, overrides [kRemoteIconCircleButtonIconSize] for [imageAsset] only.
  final double? imageIconSize;
  final Color? brandColor;
  final String? label;
  /// When null, the button is shown in a disabled (non-interactive) state.
  final VoidCallback? onPressed;
  final bool isPower;
  final Color? backgroundColor;
  final Color? foregroundColor;
  /// When set with [onPressed], drives category-aware haptic feedback on press.
  final RemoteCommand? interactionCommand;
  /// Custom haptic when no [interactionCommand] is available.
  final VoidCallback? onPressHaptic;

  @override
  Widget build(BuildContext context) {
    assert(
      icon != null || label != null || imageAsset != null,
      'Either icon, imageAsset, or label must be provided.',
    );
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = AppTheme.colorsOf(context);
    final background =
        backgroundColor ??
        (isPower ? appColors.remotePowerFill : appColors.remoteSurface);
    final iconColor = foregroundColor ??
        (isPower ? appColors.remoteGlyphOnPower : colorScheme.onSurface);
    final Widget child;
    if (imageAsset != null) {
      final imageSize =
          imageIconSize ?? kRemoteIconCircleButtonIconSize;
      child = SvgPicture.asset(
        imageAsset!,
        width: imageSize,
        height: imageSize,
        fit: BoxFit.contain,
        colorFilter: brandColor != null
            ? ColorFilter.mode(brandColor!, BlendMode.srcIn)
            : null,
      );
    } else if (icon != null) {
      child = Icon(
        icon,
        color: iconColor,
        size: kRemoteIconCircleButtonIconSize,
      );
    } else {
      child = Text(
        label!,
        style: TextStyle(
          color: iconColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );
    }

    final buttonBody = Container(
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
      child: Center(child: child),
    );

    if (onPressed == null) {
      return buttonBody;
    }

    return RemotePressFeedback(
      onPressed: onPressed,
      onPressHaptic: interactionCommand != null
          ? () => RemoteCommandHapticFeedback.playFor(interactionCommand!)
          : onPressHaptic,
      child: buttonBody,
    );
  }
}
