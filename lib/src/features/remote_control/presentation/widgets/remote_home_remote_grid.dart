import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_circular_dpad.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_icon_circle_button.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_vertical_rocker.dart';
import 'package:one_remote/src/theme/app_theme.dart';

/// Renders the interactive remote control grid for the home screen.
class RemoteHomeRemoteGrid extends StatelessWidget {
  const RemoteHomeRemoteGrid({
    super.key,
    required this.layoutItems,
    required this.gridColumns,
    required this.gridRows,
    required this.gridGap,
    required this.hasActiveDevice,
    required this.onSendCommand,
    required this.onOpenPairing,
    required this.onSearchInputPressed,
  });

  final List<LayoutEditItem> layoutItems;
  final int gridColumns;
  final int gridRows;
  final double gridGap;
  final bool hasActiveDevice;
  final void Function(RemoteCommand command) onSendCommand;
  final VoidCallback onOpenPairing;
  final VoidCallback onSearchInputPressed;

  static const Map<String, RemoteCommand> _commandByItemId = <String, RemoteCommand>{
    'home': RemoteCommand.home,
    'power': RemoteCommand.power,
    'back': RemoteCommand.back,
    'menu': RemoteCommand.menu,
    'www': RemoteCommand.web,
    'netflix': RemoteCommand.netflix,
    'prime': RemoteCommand.primeVideo,
    'disney': RemoteCommand.disneyPlus,
    'mute': RemoteCommand.mute,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final cellSize = _fitCellSize(maxWidth: maxWidth, maxHeight: maxHeight);
        final gridWidth =
            (gridColumns * cellSize) + ((gridColumns - 1) * gridGap);
        final gridHeight =
            (gridRows * cellSize) + ((gridRows - 1) * gridGap);

        return Center(
          child: SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: Stack(
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
              ],
            ),
          ),
        );
      },
    );
  }

  double _fitCellSize({required double maxWidth, required double maxHeight}) {
    final widthLimited = (maxWidth - ((gridColumns - 1) * gridGap)) / gridColumns;
    final heightLimited = (maxHeight - ((gridRows - 1) * gridGap)) / gridRows;
    return math.max(1, math.min(widthLimited, heightLimited));
  }

  Widget _buildRemoteLayoutItem({
    required BuildContext context,
    required LayoutEditItem item,
    required double cellSize,
  }) {
    switch (item.id) {
      case 'dpad':
        return _buildDpadItem(item, cellSize);
      case 'searchInput':
        return _buildSearchInputItem(item, cellSize);
      case 'playPause':
        return _buildPlayPauseItem(context, item, cellSize);
      case 'channel':
        return _buildChannelItem(item, cellSize);
      case 'volume':
        return _buildVolumeItem(item, cellSize);
      case 'pair':
        return _buildPairItem(context, item, cellSize);
      default:
        final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
        final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
        final command = _commandByItemId[item.id];
        final onPressed = command == null
            ? _noopAction
            : () => onSendCommand(command);
        return SizedBox(
          width: width,
          height: height,
          child: RemoteIconCircleButton(
            icon: item.icon,
            label: item.label,
            isPower: item.isPower,
            onPressed: onPressed,
          ),
        );
    }
  }

  Widget _buildDpadItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: RemoteCircularDpad(
          onUp: () => onSendCommand(RemoteCommand.dpadUp),
          onDown: () => onSendCommand(RemoteCommand.dpadDown),
          onLeft: () => onSendCommand(RemoteCommand.dpadLeft),
          onRight: () => onSendCommand(RemoteCommand.dpadRight),
          onOk: () => onSendCommand(RemoteCommand.dpadOk),
        ),
      ),
    );
  }

  Widget _buildSearchInputItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
    final definition = kRemoteLayoutItemDefinitionById[item.id];
    final keyboardIcon = definition?.icon ?? item.icon ?? Icons.keyboard_outlined;
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: RemoteIconCircleButton(
          icon: keyboardIcon,
          onPressed: onSearchInputPressed,
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
    final glyphSize = math.min(width, height) * 0.24;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: appColors.remoteSurface,
        borderRadius: BorderRadius.circular(height / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: () => onSendCommand(RemoteCommand.playPause),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: appColors.remoteOutline, width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: glyphSize + 2,
                ),
                SizedBox(width: math.max(1, glyphSize * 0.08)),
                Icon(Icons.pause, color: Colors.white, size: glyphSize + 1),
              ],
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
      child: FittedBox(
        fit: BoxFit.fill,
        child: RemoteVerticalRocker(
          topText: '+',
          centerText: 'CH',
          bottomText: '-',
          onTopTap: () => onSendCommand(RemoteCommand.channelUp),
          onBottomTap: () => onSendCommand(RemoteCommand.channelDown),
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
      child: FittedBox(
        fit: BoxFit.fill,
        child: RemoteVerticalRocker(
          topText: '+',
          centerText: 'VOL',
          bottomText: '-',
          onTopTap: () => onSendCommand(RemoteCommand.volumeUp),
          onBottomTap: () => onSendCommand(RemoteCommand.volumeDown),
        ),
      ),
    );
  }

  Widget _buildPairItem(
    BuildContext context,
    LayoutEditItem item,
    double cellSize,
  ) {
    final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
    return SizedBox(
      width: width,
      height: height,
      child: RemoteIconCircleButton(
        icon: item.icon,
        label: item.label,
        onPressed: onOpenPairing,
        backgroundColor: hasActiveDevice
            ? Colors.green.shade600
            : AppTheme.colorsOf(context).remoteSurface,
        foregroundColor: Colors.white,
      ),
    );
  }

  static void _noopAction() {}
}
