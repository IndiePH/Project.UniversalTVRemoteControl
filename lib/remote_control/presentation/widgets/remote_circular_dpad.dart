import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_command_haptic_feedback.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_press_feedback.dart';
import 'package:one_remote/theme/app_theme.dart';

class RemoteCircularDpad extends StatelessWidget {
  const RemoteCircularDpad({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onOk,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final appColors = AppTheme.colorsOf(context);
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appColors.remoteSurface,
              border: Border.all(color: appColors.remoteOutline, width: 1.4),
            ),
          ),
          _ArrowButton(
            alignment: Alignment.topCenter,
            icon: Icons.keyboard_arrow_up,
            iconPadding: const EdgeInsets.only(bottom: 16),
            onTap: onUp,
            iconColor: appColors.remoteGlyphOnRemote,
            interactionCommand: RemoteCommand.dpadUp,
          ),
          _ArrowButton(
            alignment: Alignment.bottomCenter,
            icon: Icons.keyboard_arrow_down,
            iconPadding: const EdgeInsets.only(top: 16),
            onTap: onDown,
            iconColor: appColors.remoteGlyphOnRemote,
            interactionCommand: RemoteCommand.dpadDown,
          ),
          _ArrowButton(
            alignment: Alignment.centerLeft,
            icon: Icons.keyboard_arrow_left,
            iconPadding: const EdgeInsets.only(right: 16),
            onTap: onLeft,
            iconColor: appColors.remoteGlyphOnRemote,
            interactionCommand: RemoteCommand.dpadLeft,
          ),
          _ArrowButton(
            alignment: Alignment.centerRight,
            icon: Icons.keyboard_arrow_right,
            iconPadding: const EdgeInsets.only(left: 16),
            onTap: onRight,
            iconColor: appColors.remoteGlyphOnRemote,
            interactionCommand: RemoteCommand.dpadRight,
          ),
          RemotePressFeedback(
            onPressed: onOk,
            onPressHaptic: () =>
                RemoteCommandHapticFeedback.playFor(RemoteCommand.dpadOk),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appColors.remoteRaisedSurface,
                border: Border.all(color: appColors.remoteOutline, width: 1.4),
              ),
              child: Center(
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: appColors.remoteGlyphOnRemote,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.alignment,
    required this.icon,
    required this.onTap,
    required this.iconColor,
    required this.interactionCommand,
    this.iconPadding = EdgeInsets.zero,
  });

  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final RemoteCommand interactionCommand;
  final EdgeInsets iconPadding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 82,
        height: 82,
        child: RemotePressFeedback(
          onPressed: onTap,
          onPressHaptic: () =>
              RemoteCommandHapticFeedback.playFor(interactionCommand),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: Padding(
              padding: iconPadding,
              child: Icon(icon, size: 46, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
