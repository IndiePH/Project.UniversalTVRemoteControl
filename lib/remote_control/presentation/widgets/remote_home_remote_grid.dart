import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_command_haptic_feedback.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_command_interaction_category.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_press_feedback.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_circular_dpad.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_icon_circle_button.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_button_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor_grid_geometry.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_pairing_hint_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_vertical_rocker.dart';
import 'package:one_remote/theme/app_theme.dart';

/// Renders the interactive remote control grid for the home screen.
class RemoteHomeRemoteGrid extends StatelessWidget {
  const RemoteHomeRemoteGrid({
    super.key,
    required this.layoutItems,
    required this.gridColumns,
    required this.gridRows,
    required this.gridGap,
    required this.controlsEnabled,
    required this.pairingHintActive,
    required this.onSendCommand,
    required this.onSearchInputPressed,
    required this.onDisabledInteraction,
    this.onInterstitialTestPressed,
    this.onProToggleTestPressed,
    this.proToggleTestIsPro = false,
  });

  final List<LayoutEditItem> layoutItems;
  final int gridColumns;
  final int gridRows;
  final double gridGap;
  final bool controlsEnabled;
  final bool pairingHintActive;
  final void Function(RemoteCommand command) onSendCommand;
  final VoidCallback onSearchInputPressed;
  final VoidCallback onDisabledInteraction;
  /// Debug-only: tap target immediately right of the power button (grid `[1,0]`).
  final VoidCallback? onInterstitialTestPressed;
  /// Debug-only: tap target immediately below the power button (grid `[0,1]`).
  final VoidCallback? onProToggleTestPressed;
  final bool proToggleTestIsPro;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final cellSize = RemoteLayoutEditorGridGeometry.fitCellSize(
          gridColumns: gridColumns,
          gridRows: gridRows,
          gridGap: gridGap,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
        final gridWidth =
            (gridColumns * cellSize) + ((gridColumns - 1) * gridGap);
        final gridHeight = (gridRows * cellSize) + ((gridRows - 1) * gridGap);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: kRemotePairingHintFadeDuration,
                  child: Stack(
                    key: ValueKey<bool>(pairingHintActive),
                    children: [
                      for (final item in layoutItems)
                        Positioned(
                          left: item.col * (cellSize + gridGap),
                          top: item.row * (cellSize + gridGap),
                          child: _buildRemoteLayoutItem(
                            context: context,
                            item: item,
                            cellSize: cellSize,
                          ),
                        ),
                      if (onInterstitialTestPressed != null)
                        Positioned(
                          left: cellSize + gridGap,
                          top: 0,
                          child: _buildInterstitialTestButton(
                            context: context,
                            cellSize: cellSize,
                            onPressed: onInterstitialTestPressed!,
                          ),
                        ),
                      if (onProToggleTestPressed != null)
                        Positioned(
                          left: 0,
                          top: cellSize + gridGap,
                          child: _buildProToggleTestButton(
                            context: context,
                            cellSize: cellSize,
                            isPro: proToggleTestIsPro,
                            onPressed: onProToggleTestPressed!,
                          ),
                        ),
                    ],
                  ),
                ),
                if (pairingHintActive && !controlsEnabled)
                  const Positioned.fill(
                    child: AbsorbPointer(
                      absorbing: true,
                      child: SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemoteLayoutItem({
    required BuildContext context,
    required LayoutEditItem item,
    required double cellSize,
  }) {
    final Widget itemWidget;
    switch (item.id) {
      case 'dpad':
        itemWidget = _buildDpadItem(item, cellSize);
        break;
      case 'searchInput':
        itemWidget = _buildSearchInputItem(item, cellSize);
        break;
      case 'playPause':
        itemWidget = _buildPlayPauseItem(context, item, cellSize);
        break;
      case 'channel':
        itemWidget = _buildChannelItem(item, cellSize);
        break;
      case 'volume':
        itemWidget = _buildVolumeItem(item, cellSize);
        break;
      default:
        final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
        final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
        final definition = kRemoteLayoutItemDefinitionById[item.id];
        final command = commandForLayoutItemId(item.id);
        final onPressed = command == null
            ? _noopAction
            : controlsEnabled
            ? () => onSendCommand(command)
            : pairingHintActive
            ? null
            : onDisabledInteraction;
        itemWidget = SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: EdgeInsets.all(cellSize * kRemoteLayoutCellInsetRatio),
            child: FittedBox(
              fit: BoxFit.contain,
              child: RemoteIconCircleButton(
                icon: item.icon,
                imageAsset: definition?.imageAsset ?? item.imageAsset,
                imageIconSize: definition?.imageIconSize,
                brandColor: definition?.brandColor,
                label: item.label,
                isPower: controlsEnabled && item.isPower,
                onPressed: onPressed,
                interactionCommand: command,
              ),
            ),
          ),
        );
        break;
    }
    return _applyDisabledStyle(context, itemWidget);
  }

  Widget _buildDpadItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: EdgeInsets.all(cellSize * kRemoteLayoutCellInsetRatio),
        child: FittedBox(
          fit: BoxFit.contain,
          child: RemoteCircularDpad(
            onUp: controlsEnabled
                ? () => onSendCommand(RemoteCommand.dpadUp)
                : pairingHintActive
                ? _noopAction
                : onDisabledInteraction,
            onDown: controlsEnabled
                ? () => onSendCommand(RemoteCommand.dpadDown)
                : pairingHintActive
                ? _noopAction
                : onDisabledInteraction,
            onLeft: controlsEnabled
                ? () => onSendCommand(RemoteCommand.dpadLeft)
                : pairingHintActive
                ? _noopAction
                : onDisabledInteraction,
            onRight: controlsEnabled
                ? () => onSendCommand(RemoteCommand.dpadRight)
                : pairingHintActive
                ? _noopAction
                : onDisabledInteraction,
            onOk: controlsEnabled
                ? () => onSendCommand(RemoteCommand.dpadOk)
                : pairingHintActive
                ? _noopAction
                : onDisabledInteraction,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInputItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
    final definition = kRemoteLayoutItemDefinitionById[item.id];
    final keyboardIcon =
        definition?.icon ?? item.icon ?? Icons.keyboard_outlined;
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: EdgeInsets.all(cellSize * kRemoteLayoutCellInsetRatio),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: RemoteIconCircleButton(
              icon: keyboardIcon,
              onPressed: controlsEnabled
                  ? onSearchInputPressed
                  : pairingHintActive
                  ? null
                  : onDisabledInteraction,
              onPressHaptic: controlsEnabled
                  ? () => RemoteCommandHapticFeedback.playForCategory(
                      RemoteCommandInteractionCategory.system,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseItem(
    BuildContext context,
    LayoutEditItem item,
    double cellSize,
  ) {
    final appColors = AppTheme.colorsOf(context);
    final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
    final inset = cellSize * kRemoteLayoutCellInsetRatio;
    final innerHeight = math.max(1.0, height - inset * 2);
    final glyphSize = math.min(math.max(1.0, width - inset * 2), innerHeight) *
        kRemotePlayPauseGlyphSizeRatio;
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: Material(
          color: appColors.remoteSurface,
          borderRadius: BorderRadius.circular(innerHeight / 2),
          child: RemotePressFeedback(
            onPressed: controlsEnabled
                ? () => onSendCommand(RemoteCommand.playPause)
                : pairingHintActive
                ? null
                : onDisabledInteraction,
            onPressHaptic: controlsEnabled
                ? () => RemoteCommandHapticFeedback.playFor(
                    RemoteCommand.playPause,
                  )
                : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(innerHeight / 2),
                border: Border.all(
                  color: appColors.remoteOutline,
                  width: kRemoteIconCircleButtonBorderWidth,
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: kRemotePlayPauseInnerHorizontalPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow,
                    color: appColors.remoteGlyphOnRemote,
                    size: glyphSize + kRemotePlayPausePlayGlyphBoost,
                  ),
                  SizedBox(
                    width: math.max(1, glyphSize * kRemotePlayPauseGlyphGapRatio),
                  ),
                  Icon(
                    Icons.pause,
                    color: appColors.remoteGlyphOnRemote,
                    size: glyphSize + kRemotePlayPausePauseGlyphBoost,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: EdgeInsets.all(cellSize * kRemoteLayoutCellInsetRatio),
        child: FittedBox(
          fit: BoxFit.fill,
          child: RemoteVerticalRocker(
            topText: '+',
            centerText: 'CH',
            bottomText: '-',
            onTopTap: controlsEnabled
                ? () => onSendCommand(RemoteCommand.channelUp)
                : pairingHintActive
                ? _noopAction
                : onDisabledInteraction,
            onBottomTap: controlsEnabled
                ? () => onSendCommand(RemoteCommand.channelDown)
                : pairingHintActive
                ? _noopAction
                : onDisabledInteraction,
            topInteractionCommand: RemoteCommand.channelUp,
            bottomInteractionCommand: RemoteCommand.channelDown,
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: EdgeInsets.all(cellSize * kRemoteLayoutCellInsetRatio),
        child: FittedBox(
          fit: BoxFit.fill,
          child: RemoteVerticalRocker(
            topText: '+',
            centerText: 'VOL',
            bottomText: '-',
            onTopTap: controlsEnabled
                ? () => onSendCommand(RemoteCommand.volumeUp)
                : pairingHintActive
                ? _noopAction
                : onDisabledInteraction,
            onBottomTap: controlsEnabled
                ? () => onSendCommand(RemoteCommand.volumeDown)
                : pairingHintActive
                ? _noopAction
                : onDisabledInteraction,
            topInteractionCommand: RemoteCommand.volumeUp,
            bottomInteractionCommand: RemoteCommand.volumeDown,
          ),
        ),
      ),
    );
  }

  Widget _buildProToggleTestButton({
    required BuildContext context,
    required double cellSize,
    required bool isPro,
    required VoidCallback onPressed,
  }) {
    final width = cellSize;
    final height = cellSize;
    final appColors = AppTheme.colorsOf(context);
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: EdgeInsets.all(cellSize * kRemoteLayoutCellInsetRatio),
        child: FittedBox(
          fit: BoxFit.contain,
          child: RemoteIconCircleButton(
            label: isPro ? 'PRO' : 'FREE',
            backgroundColor: isPro ? appColors.remotePowerFill : null,
            foregroundColor: isPro ? appColors.remoteGlyphOnPower : null,
            onPressed: onPressed,
            onPressHaptic: () => RemoteCommandHapticFeedback.playForCategory(
              RemoteCommandInteractionCategory.system,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterstitialTestButton({
    required BuildContext context,
    required double cellSize,
    required VoidCallback onPressed,
  }) {
    final width = cellSize;
    final height = cellSize;
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: EdgeInsets.all(cellSize * kRemoteLayoutCellInsetRatio),
        child: FittedBox(
          fit: BoxFit.contain,
          child: RemoteIconCircleButton(
            icon: Icons.ad_units_outlined,
            onPressed: onPressed,
            onPressHaptic: () => RemoteCommandHapticFeedback.playForCategory(
              RemoteCommandInteractionCategory.system,
            ),
          ),
        ),
      ),
    );
  }

  Widget _applyDisabledStyle(BuildContext context, Widget child) {
    if (controlsEnabled) {
      return child;
    }
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        AppTheme.colorsOf(context).remoteDisabledControlTint.withValues(
          alpha: 0.42,
        ),
        BlendMode.modulate,
      ),
      child: Opacity(opacity: 0.58, child: child),
    );
  }

  static void _noopAction() {}
}
