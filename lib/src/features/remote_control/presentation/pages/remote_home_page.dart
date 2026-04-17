import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_repository.dart';
import 'package:one_remote/src/features/remote_control/application/layout_repository.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_circular_dpad.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_icon_circle_button.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_vertical_rocker.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/pairing_page.dart';

/// Main remote screen.
///
/// Keeps UI-focused state local and delegates command/pairing work to
/// injected services so transport and storage layers stay replaceable.
class RemoteHomePage extends StatefulWidget {
  const RemoteHomePage({
    super.key,
    required this.commandService,
    required this.deviceRepository,
    required this.discoveryService,
    required this.layoutRepository,
  });

  final RemoteCommandService commandService;
  final DeviceRepository deviceRepository;
  final DeviceDiscoveryService discoveryService;
  final LayoutRepository layoutRepository;

  @override
  State<RemoteHomePage> createState() => _RemoteHomePageState();
}

class _RemoteHomePageState extends State<RemoteHomePage> {
  static const int _gridColumns = 5;
  static const int _gridRows = 9;
  static const double _gridGap = 6;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final List<_LayoutEditItem> _layoutItems = _initialLayoutItems();
  final Map<String, _DragAnchorOffset> _dragAnchorOffsetsByItemId =
      <String, _DragAnchorOffset>{};
  TvDevice? _activeDevice;
  String _status = 'Ready';
  bool _isLayoutEditMode = false;
  bool _isDraggingLayoutItem = false;
  bool _isPairingInProgress = false;

  static List<_LayoutEditItem> _initialLayoutItems() {
    return [
      _LayoutEditItem(id: 'power', icon: Icons.power_settings_new, col: 0, row: 0, isPower: true),
      _LayoutEditItem(id: 'pair', icon: Icons.wifi, col: 4, row: 0),
      _LayoutEditItem(id: 'menu', label: 'MENU', col: 2, row: 0),
      _LayoutEditItem(
        id: 'volume',
        label: 'VOL',
        col: 0,
        row: 3,
        height: 3,
      ),
      _LayoutEditItem(id: 'playPause', label: '|>||', col: 1, row: 2),
      _LayoutEditItem(id: 'www', label: 'WWW', col: 3, row: 2),
      _LayoutEditItem(id: 'dpad', label: 'DPAD', col: 1, row: 3, width: 3, height: 3),
      _LayoutEditItem(id: 'channel', label: 'CH', col: 4, row: 3, height: 3),
      _LayoutEditItem(id: 'home', icon: Icons.home_outlined, col: 2, row: 1),
      _LayoutEditItem(id: 'back', icon: Icons.arrow_back, col: 0, row: 6),
      _LayoutEditItem(id: 'mute', icon: Icons.volume_off, col: 4, row: 6),
      _LayoutEditItem(id: 'netflix', icon: Icons.movie_filter, col: 1, row: 7),
      _LayoutEditItem(id: 'disney', icon: Icons.live_tv, col: 2, row: 7),
      _LayoutEditItem(id: 'prime', icon: Icons.video_library_outlined, col: 3, row: 7),
      _LayoutEditItem(
        id: 'searchInput',
        label: 'SEARCH',
        col: 0,
        row: 8,
        width: 5,
        height: 1,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadInitialDevice();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialDevice() async {
    final lastUsed = await widget.deviceRepository.getLastUsedDevice();
    if (!mounted || lastUsed == null) {
      return;
    }
    final lastPairedAt = await widget.deviceRepository.getLastSuccessfulPairingAt(
      lastUsed.id,
    );
    setState(() {
      _activeDevice = lastUsed;
      _status = _statusForConnectedDevice(lastUsed.displayName, lastPairedAt);
    });
    await _loadLayoutForDevice(lastUsed.id);
  }

  Future<bool> _send(RemoteCommand command) async {
    final device = _activeDevice;
    if (device == null) {
      setState(() {
        _status = 'No device selected.';
      });
      _showToast('No device selected.', isError: true);
      return false;
    }
    final result = await widget.commandService.sendCommand(
      device: device,
      command: command,
    );
    if (!mounted) {
      return false;
    }
    setState(() {
      _status = result.message;
    });
    if (!result.isSuccess) {
      _showToast(result.message, isError: true);
    }
    return result.isSuccess;
  }

  Future<void> _sendText() async {
    final device = _activeDevice;
    final text = _textController.text.trim();
    if (device == null) {
      setState(() {
        _status = 'No device selected.';
      });
      _showToast('No device selected.', isError: true);
      return;
    }
    if (text.isEmpty) {
      setState(() {
        _status = 'Enter text before sending.';
      });
      _showToast('Enter text before sending.', isError: true);
      return;
    }
    if (!device.capabilities.contains(DeviceCapability.textInput)) {
      setState(() {
        _status = 'Text input is not supported on this device.';
      });
      _showToast('Text input is not supported on this device.', isError: true);
      return;
    }

    final result = await widget.commandService.sendText(device: device, text: text);
    if (!mounted) {
      return;
    }
    setState(() {
      _status = result.message;
      if (result.isSuccess) {
        _textController.clear();
      }
    });
    if (!result.isSuccess) {
      _showToast(result.message, isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? colorScheme.error : null,
        ),
      );
  }

  Future<void> _openPairing() async {
    if (_isPairingInProgress) {
      return;
    }
    // Pairing returns a selected device (or null on cancel). Persist then switch context.
    final selectedDevice = await Navigator.of(context).push<TvDevice>(
      MaterialPageRoute(
        builder: (_) => PairingPage(
          discoveryService: widget.discoveryService,
          deviceRepository: widget.deviceRepository,
          activeDeviceId: _activeDevice?.id,
        ),
      ),
    );
    if (!mounted || selectedDevice == null) {
      return;
    }
    setState(() {
      _isPairingInProgress = true;
      _status = 'Pairing ${selectedDevice.displayName}...';
    });
    try {
      await widget.deviceRepository.saveDevice(selectedDevice);
      await widget.deviceRepository.setLastUsedDevice(selectedDevice.id);
      final pairedAt = DateTime.now();
      await widget.deviceRepository.setLastSuccessfulPairingAt(
        deviceId: selectedDevice.id,
        timestamp: pairedAt,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeDevice = selectedDevice;
        _status = _statusForPairedDevice(selectedDevice.displayName, pairedAt);
      });
      await _loadLayoutForDevice(selectedDevice.id);
    } finally {
      if (mounted) {
        setState(() {
          _isPairingInProgress = false;
        });
      }
    }
  }

  String _statusForConnectedDevice(String deviceName, DateTime? lastPairedAt) {
    final formatted = _formatTimestamp(lastPairedAt);
    if (formatted == null) {
      return 'Connected: $deviceName';
    }
    return 'Connected: $deviceName (last paired $formatted)';
  }

  String _statusForPairedDevice(String deviceName, DateTime pairedAt) {
    final formatted = _formatTimestamp(pairedAt);
    if (formatted == null) {
      return 'Paired: $deviceName';
    }
    return 'Paired: $deviceName at $formatted';
  }

  String? _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return null;
    }
    final local = timestamp.toLocal();
    final date = '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
    final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    return '$date $time';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  void _toggleLayoutEditMode() {
    setState(() {
      _isLayoutEditMode = !_isLayoutEditMode;
      _status = _isLayoutEditMode
          ? 'Layout edit mode: drag buttons on the 5x8 grid.'
          : 'Layout edit mode disabled.';
    });
    if (!_isLayoutEditMode) {
      unawaited(_persistLayoutForActiveDevice());
    }
  }

  void _resetLayoutToDefaults() {
    _layoutItems
      ..clear()
      ..addAll(_initialLayoutItems());
  }

  Future<void> _loadLayoutForDevice(String deviceId) async {
    _resetLayoutToDefaults();
    final saved = await widget.layoutRepository.loadLayout(deviceId: deviceId);

    for (final item in _layoutItems) {
      final position = saved[item.id];
      if (position == null) {
        continue;
      }
      if (!_canPlaceItem(
        item: item,
        col: position.col,
        row: position.row,
        ignoreIds: {item.id},
      )) {
        continue;
      }
      item.col = position.col;
      item.row = position.row;
    }

    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _persistLayoutForActiveDevice() async {
    final deviceId = _activeDevice?.id;
    if (deviceId == null || deviceId.isEmpty) {
      return;
    }
    final positions = <String, LayoutPosition>{
      for (final item in _layoutItems)
        item.id: LayoutPosition(col: item.col, row: item.row),
    };
    await widget.layoutRepository.saveLayout(
      deviceId: deviceId,
      positionsByItemId: positions,
    );
  }

  Future<void> _resetLayoutForActiveDevice() async {
    _resetLayoutToDefaults();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = 'Layout reset to defaults.';
    });
    await _persistLayoutForActiveDevice();
  }

  bool _canPlaceItem({
    required _LayoutEditItem item,
    required int col,
    required int row,
    Set<String> ignoreIds = const {},
  }) {
    if (col < 0 || row < 0) {
      return false;
    }
    if (col + item.width > _gridColumns || row + item.height > _gridRows) {
      return false;
    }

    for (final other in _layoutItems) {
      if (other.id == item.id || ignoreIds.contains(other.id)) {
        continue;
      }
      final overlaps = col < other.col + other.width &&
          col + item.width > other.col &&
          row < other.row + other.height &&
          row + item.height > other.row;
      if (overlaps) {
        return false;
      }
    }
    return true;
  }

  _LayoutEditItem? _itemAtCell({required int col, required int row}) {
    for (final item in _layoutItems) {
      final contains = col >= item.col &&
          col < item.col + item.width &&
          row >= item.row &&
          row < item.row + item.height;
      if (contains) {
        return item;
      }
    }
    return null;
  }

  void _recordDragAnchor({
    required _LayoutEditItem item,
    required Offset localPosition,
    required double cellSize,
  }) {
    final stride = cellSize + _gridGap;
    final colOffset = (localPosition.dx / stride).floor().clamp(0, item.width - 1);
    final rowOffset = (localPosition.dy / stride).floor().clamp(0, item.height - 1);
    _dragAnchorOffsetsByItemId[item.id] = _DragAnchorOffset(
      colOffset: colOffset,
      rowOffset: rowOffset,
    );
  }

  _DragAnchorOffset _dragAnchorForItem(String itemId) {
    return _dragAnchorOffsetsByItemId[itemId] ??
        const _DragAnchorOffset(colOffset: 0, rowOffset: 0);
  }

  Widget _buildLayoutEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Layout Editor',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => unawaited(_resetLayoutForActiveDevice()),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Layout'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Drag buttons to new positions. Grid: 5x9. D-pad uses 3x3 cells.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildLayoutGridCanvas()),
      ],
    );
  }

  Widget _buildLayoutGridCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final cellSize = _fitCellSize(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
        final gridWidth = (_gridColumns * cellSize) + ((_gridColumns - 1) * _gridGap);
        final gridHeight = (_gridRows * cellSize) + ((_gridRows - 1) * _gridGap);

        return Center(
          child: SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: Stack(
              children: [
              for (var row = 0; row < _gridRows; row++)
                for (var col = 0; col < _gridColumns; col++)
                  Positioned(
                    left: col * (cellSize + _gridGap),
                    top: row * (cellSize + _gridGap),
                    child: DragTarget<String>(
                      onWillAcceptWithDetails: (details) {
                        final moving = _layoutItems
                            .where((item) => item.id == details.data)
                            .firstOrNull;
                        if (moving == null) {
                          return false;
                        }
                        final anchor = _dragAnchorForItem(moving.id);
                        final dropCol = col - anchor.colOffset;
                        final dropRow = row - anchor.rowOffset;
                        final target = _itemAtCell(col: col, row: row);
                        if (target == null || target.id == moving.id) {
                          return _canPlaceItem(
                            item: moving,
                            col: dropCol,
                            row: dropRow,
                          );
                        }

                        // Swap candidate: moving goes to target cell, target goes to moving origin.
                        final canPlaceMoving = _canPlaceItem(
                          item: moving,
                          col: dropCol,
                          row: dropRow,
                          ignoreIds: {target.id},
                        );
                        final canPlaceTarget = _canPlaceItem(
                          item: target,
                          col: moving.col,
                          row: moving.row,
                          ignoreIds: {moving.id},
                        );
                        return canPlaceMoving && canPlaceTarget;
                      },
                      onAcceptWithDetails: (details) {
                        final moving = _layoutItems
                            .where((item) => item.id == details.data)
                            .firstOrNull;
                        if (moving == null) {
                          return;
                        }
                        final anchor = _dragAnchorForItem(moving.id);
                        final dropCol = col - anchor.colOffset;
                        final dropRow = row - anchor.rowOffset;
                        final target = _itemAtCell(col: col, row: row);
                        final movingOldCol = moving.col;
                        final movingOldRow = moving.row;

                        if (target == null || target.id == moving.id) {
                          if (!_canPlaceItem(
                            item: moving,
                            col: dropCol,
                            row: dropRow,
                          )) {
                            return;
                          }
                          setState(() {
                            moving.col = dropCol;
                            moving.row = dropRow;
                          });
                          unawaited(_persistLayoutForActiveDevice());
                          return;
                        }

                        final canPlaceMoving = _canPlaceItem(
                          item: moving,
                          col: dropCol,
                          row: dropRow,
                          ignoreIds: {target.id},
                        );
                        final canPlaceTarget = _canPlaceItem(
                          item: target,
                          col: movingOldCol,
                          row: movingOldRow,
                          ignoreIds: {moving.id},
                        );
                        if (!canPlaceMoving || !canPlaceTarget) {
                          return;
                        }
                        setState(() {
                          moving.col = dropCol;
                          moving.row = dropRow;
                          target.col = movingOldCol;
                          target.row = movingOldRow;
                        });
                        unawaited(_persistLayoutForActiveDevice());
                      },
                      builder: (context, _, rejectedData) {
                        return Container(
                          width: cellSize,
                          height: cellSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFF171A20),
                            borderRadius: BorderRadius.circular(cellSize * 0.2),
                            border: Border.all(color: const Color(0xFF2D3138)),
                          ),
                        );
                      },
                    ),
                  ),
                for (final item in _layoutItems)
                  Positioned(
                    left: item.col * (cellSize + _gridGap),
                    top: item.row * (cellSize + _gridGap),
                    child: IgnorePointer(
                    // While dragging, let grid DragTargets receive hit tests.
                    ignoring: _isDraggingLayoutItem,
                    child: Draggable<String>(
                      data: item.id,
                      onDragStarted: () {
                        setState(() {
                          _isDraggingLayoutItem = true;
                        });
                      },
                      onDragEnd: (_) {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _isDraggingLayoutItem = false;
                        });
                      },
                      feedback: Material(
                        color: Colors.transparent,
                        child: Opacity(
                          opacity: 0.85,
                          child: _buildGridItemTile(item: item, cellSize: cellSize),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: _buildGridItemTile(item: item, cellSize: cellSize),
                      ),
                      child: Listener(
                        onPointerDown: (event) {
                          _recordDragAnchor(
                            item: item,
                            localPosition: event.localPosition,
                            cellSize: cellSize,
                          );
                        },
                        child: _buildGridItemTile(item: item, cellSize: cellSize),
                      ),
                    ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridItemTile({
    required _LayoutEditItem item,
    required double cellSize,
  }) {
    final width = (item.width * cellSize) + ((item.width - 1) * _gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * _gridGap);
    final background = item.isPower ? Colors.red.shade600 : const Color(0xFF1B1D22);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: item.width == 1 && item.height == 1 ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: item.width == 1 && item.height == 1
            ? null
            : BorderRadius.circular(cellSize * 0.6),
        color: background,
        border: Border.all(color: const Color(0xFF2D3138), width: 1.2),
      ),
      child: item.id == 'playPause'
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_arrow,
                  size: math.min(width, height) * 0.34,
                  color: Colors.white,
                ),
                SizedBox(width: math.max(1, math.min(width, height) * 0.04)),
                Icon(
                  Icons.pause,
                  size: math.min(width, height) * 0.30,
                  color: Colors.white,
                ),
              ],
            )
          : item.icon != null
              ? Icon(item.icon, size: math.min(width, height) * 0.45, color: Colors.white)
              : Center(
                  child: Text(
                    item.label ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
    );
  }

  Widget _buildRemoteLayoutCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final cellSize = _fitCellSize(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
        final gridWidth = (_gridColumns * cellSize) + ((_gridColumns - 1) * _gridGap);
        final gridHeight = (_gridRows * cellSize) + ((_gridRows - 1) * _gridGap);

        return Center(
          child: SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: Stack(
              children: [
              for (final item in _layoutItems)
                Positioned(
                  left: item.col * (cellSize + _gridGap),
                  top: item.row * (cellSize + _gridGap),
                  child: _buildRemoteLayoutItem(item: item, cellSize: cellSize),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _fitCellSize({
    required double maxWidth,
    required double maxHeight,
  }) {
    final widthLimited =
        (maxWidth - ((_gridColumns - 1) * _gridGap)) / _gridColumns;
    final heightLimited =
        (maxHeight - ((_gridRows - 1) * _gridGap)) / _gridRows;
    return math.max(1, math.min(widthLimited, heightLimited));
  }

  Widget _buildRemoteLayoutItem({
    required _LayoutEditItem item,
    required double cellSize,
  }) {
    final width = (item.width * cellSize) + ((item.width - 1) * _gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * _gridGap);

    if (item.id == 'dpad') {
      return SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.contain,
          child: RemoteCircularDpad(
            onUp: () => _send(RemoteCommand.dpadUp),
            onDown: () => _send(RemoteCommand.dpadDown),
            onLeft: () => _send(RemoteCommand.dpadLeft),
            onRight: () => _send(RemoteCommand.dpadRight),
            onOk: () => _send(RemoteCommand.dpadOk),
          ),
        ),
      );
    }

    if (item.id == 'searchInput') {
      return SizedBox(
        width: width,
        height: height,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1D22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2D3138), width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: double.infinity,
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFocusNode,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Type search text',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.send,
                    onTap: () => _textFocusNode.requestFocus(),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: _sendText,
                    child: const Icon(Icons.search),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (item.id == 'playPause') {
      final glyphSize = math.min(width, height) * 0.24;
      return SizedBox(
        width: width,
        height: height,
        child: Material(
          color: const Color(0xFF1B1D22),
          borderRadius: BorderRadius.circular(height / 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: () => _send(RemoteCommand.playPause),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(color: const Color(0xFF2D3138), width: 1.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, color: Colors.white, size: glyphSize + 2),
                  SizedBox(width: math.max(1, glyphSize * 0.08)),
                  Icon(Icons.pause, color: Colors.white, size: glyphSize + 1),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (item.id == 'channel') {
      return SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.fill,
          child: RemoteVerticalRocker(
            topText: '+',
            centerText: 'CH',
            bottomText: '-',
            onTopTap: () => _send(RemoteCommand.channelUp),
            onBottomTap: () => _send(RemoteCommand.channelDown),
          ),
        ),
      );
    }

    if (item.id == 'volume') {
      return SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.fill,
          child: RemoteVerticalRocker(
            topText: '+',
            centerText: 'VOL',
            bottomText: '-',
            onTopTap: () => _send(RemoteCommand.volumeUp),
            onBottomTap: () => _send(RemoteCommand.volumeDown),
          ),
        ),
      );
    }

    if (item.id == 'pair') {
      final hasActiveDevice = _activeDevice != null;
      return SizedBox(
        width: width,
        height: height,
        child: RemoteIconCircleButton(
          icon: item.icon,
          label: item.label,
          onPressed: _openPairing,
          backgroundColor: hasActiveDevice ? Colors.green.shade600 : null,
          foregroundColor: Colors.white,
        ),
      );
    }

    if (item.id == 'mute') {
      return SizedBox(
        width: width,
        height: height,
        child: RemoteIconCircleButton(
          icon: item.icon,
          label: item.label,
          onPressed: () => _send(RemoteCommand.mute),
        ),
      );
    }

    final onPressed = _actionForItem(item.id);
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

  VoidCallback _actionForItem(String id) {
    return switch (id) {
      'home' => () => _send(RemoteCommand.home),
      'power' => () => _send(RemoteCommand.power),
      'pair' => _openPairing,
      'back' => () => _send(RemoteCommand.back),
      'playPause' => () => _send(RemoteCommand.playPause),
      'menu' => () => _send(RemoteCommand.menu),
      'www' => () => _send(RemoteCommand.web),
      'netflix' => () => _send(RemoteCommand.netflix),
      'prime' => () => _send(RemoteCommand.primeVideo),
      'disney' => () => _send(RemoteCommand.disneyPlus),
      'mute' => () => _send(RemoteCommand.mute),
      'channel' => () => _send(RemoteCommand.channelUp),
      'volume' => () => _send(RemoteCommand.volumeUp),
      _ => () {},
    };
  }

  Widget _buildPairingBusyOverlay() {
    if (!_isPairingInProgress) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1D22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2D3138), width: 1.2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 12),
                Text(
                  'Pairing device...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = _activeDevice?.displayName ?? 'No TV connected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('OneRemote'),
        actions: [
          IconButton(
            onPressed: _toggleLayoutEditMode,
            icon: Icon(_isLayoutEditMode ? Icons.check : Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: _isPairingInProgress,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isLayoutEditMode
                    ? _buildLayoutEditor(context)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            deviceName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(_status),
                          const SizedBox(height: 16),
                          Expanded(child: _buildRemoteLayoutCanvas()),
                        ],
                      ),
              ),
            ),
            _buildPairingBusyOverlay(),
          ],
        ),
      ),
    );
  }
}

class _LayoutEditItem {
  _LayoutEditItem({
    required this.id,
    this.icon,
    this.label,
    required this.col,
    required this.row,
    this.width = 1,
    this.height = 1,
    this.isPower = false,
  });

  final String id;
  final IconData? icon;
  final String? label;
  int col;
  int row;
  final int width;
  final int height;
  final bool isPower;
}

class _DragAnchorOffset {
  const _DragAnchorOffset({
    required this.colOffset,
    required this.rowOffset,
  });

  final int colOffset;
  final int rowOffset;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
