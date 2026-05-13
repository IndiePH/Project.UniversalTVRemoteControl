import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_button_metrics.dart';
import 'package:one_remote/theme/app_theme.dart';

/// Circular icon-only button used in the remote home / layout-editor headers.
///
/// Sizing comes from `remote_layout_button_metrics.dart` so the pair button on
/// the home view and the layout-reset button in the editor share an identical
/// bounding box. Pair-flow specific button keeps its own animated shell but
/// references the same constants to prevent drift.
class RemoteHeaderIconButton extends StatelessWidget {
  const RemoteHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final appColors = AppTheme.colorsOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: appColors.remoteSurface,
        shape: CircleBorder(
          side: BorderSide(
            color: appColors.remoteOutline,
            width: kRemoteHeaderButtonBorderWidth,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: kRemoteHeaderButtonSize,
            height: kRemoteHeaderButtonSize,
            child: Center(
              child: Icon(
                icon,
                size: kRemoteHeaderButtonIconSize,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
