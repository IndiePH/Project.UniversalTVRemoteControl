import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_repository.dart';
import 'package:one_remote/src/features/remote_control/application/layout_repository.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/src/features/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/src/features/remote_control/domain/models/layout_position.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/src/features/remote_control/presentation/formatting/two_digit_format.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/pairing_page.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_circular_dpad.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_icon_circle_button.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_editor.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_vertical_rocker.dart';
import 'package:one_remote/src/theme/app_theme.dart';

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
    this.transportLogReader = const NoopTransportLogReader(),
    this.useFakeTransports = false,
    this.compileTimeUseFakeTransports = false,
    this.onUseFakeTransportsChanged,
  });

  final RemoteCommandService commandService;
  final DeviceRepository deviceRepository;
  final DeviceDiscoveryService discoveryService;
  final LayoutRepository layoutRepository;
  final TransportLogReader transportLogReader;

  /// Effective mode for the debug sheet; parent recreates services when this changes.
  final bool useFakeTransports;

  /// Shown for context next to [useFakeTransports] (from `--dart-define`).
  final bool compileTimeUseFakeTransports;

  /// When null, the transport toggle is hidden (e.g. isolated widget tests).
  final Future<void> Function(bool useFake)? onUseFakeTransportsChanged;

  @override
  State<RemoteHomePage> createState() => _RemoteHomePageState();
}

class _RemoteHomePageState extends State<RemoteHomePage> {
  static const int _gridColumns = 5;
  static const int _gridRows = 9;
  static const double _gridGap = 6;
  static const VoidCallback _noopAction = _emptyAction;

  final TextEditingController _textController = TextEditingController();
  final List<LayoutEditItem> _layoutItems = buildInitialRemoteLayoutItems();
  TvDevice? _activeDevice;
  String _status = 'Ready';
  bool _isLayoutEditMode = false;
  StreamSubscription<bool>? _remoteTextReadySub;
  bool _remoteTextInputReady = false;

  late final Map<String, RemoteCommand> _commandByItemId = <String, RemoteCommand>{
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

  late final Map<String, VoidCallback> _customActionByItemId = <String, VoidCallback>{
    'pair': _openPairing,
  };

  late final Map<String, Widget Function(LayoutEditItem, double)>
      _customBuilderByItemId = <String, Widget Function(LayoutEditItem, double)>{
    'dpad': _buildDpadItem,
    'searchInput': _buildSearchInputItem,
    'playPause': _buildPlayPauseItem,
    'channel': _buildChannelItem,
    'volume': _buildVolumeItem,
    'pair': _buildPairItem,
  };

  @override
  void initState() {
    super.initState();
    _loadInitialDevice();
  }

  @override
  void didUpdateWidget(RemoteHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandService != widget.commandService) {
      _subscribeRemoteTextReady(_activeDevice);
    }
  }

  @override
  void dispose() {
    _remoteTextReadySub?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _subscribeRemoteTextReady(TvDevice? device) {
    _remoteTextReadySub?.cancel();
    _remoteTextReadySub = null;
    if (device == null ||
        !device.capabilities.contains(DeviceCapability.textInput)) {
      if (mounted) {
        setState(() => _remoteTextInputReady = false);
      } else {
        _remoteTextInputReady = false;
      }
      return;
    }
    _remoteTextReadySub = widget.commandService
        .watchRemoteTextInputReady(device: device)
        .listen((ready) {
      if (!mounted) {
        return;
      }
      setState(() => _remoteTextInputReady = ready);
    });
  }

  Future<void> _loadInitialDevice() async {
    final lastUsed = await widget.deviceRepository.getLastUsedDevice();
    if (!mounted) {
      return;
    }
    if (lastUsed == null) {
      _subscribeRemoteTextReady(null);
      return;
    }
    final lastPairedAt = await widget.deviceRepository
        .getLastSuccessfulPairingAt(lastUsed.id);
    setState(() {
      _activeDevice = lastUsed;
      _status = _statusForConnectedDevice(lastUsed.displayName, lastPairedAt);
    });
    _subscribeRemoteTextReady(lastUsed);
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

    final result = await widget.commandService.sendText(
      device: device,
      text: text,
    );
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
      if (result.isCompatibilityIssue) {
        _showTextCompatibilityMessage(result.message);
      } else {
        _showToast(result.message, isError: true);
      }
    }
  }

  void _showTextCompatibilityMessage(String message) {
    if (!mounted) {
      return;
    }
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: colorScheme.onTertiaryContainer),
          ),
          duration: const Duration(seconds: 8),
          backgroundColor: colorScheme.tertiaryContainer,
        ),
      );
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
    // Pairing page handles persistence and blocking busy state before returning.
    final selectedDevice = await Navigator.of(context).push<TvDevice>(
      MaterialPageRoute(
        builder: (_) => PairingPage(
          commandService: widget.commandService,
          discoveryService: widget.discoveryService,
          deviceRepository: widget.deviceRepository,
          activeDeviceId: _activeDevice?.id,
        ),
      ),
    );
    if (!mounted || selectedDevice == null) {
      return;
    }
    final lastPairedAt = await widget.deviceRepository
        .getLastSuccessfulPairingAt(selectedDevice.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _activeDevice = selectedDevice;
      _status = _statusForConnectedDevice(
        selectedDevice.displayName,
        lastPairedAt,
      );
    });
    _subscribeRemoteTextReady(selectedDevice);
    await _loadLayoutForDevice(selectedDevice.id);
  }

  String _statusForConnectedDevice(String deviceName, DateTime? lastPairedAt) {
    final formatted = _formatTimestamp(lastPairedAt);
    if (formatted == null) {
      return 'Connected: $deviceName';
    }
    return 'Connected: $deviceName (last paired $formatted)';
  }

  String? _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return null;
    }
    final local = timestamp.toLocal();
    final date =
        '${local.year}-${formatTwoDigits(local.month)}-${formatTwoDigits(local.day)}';
    final time = '${formatTwoDigits(local.hour)}:${formatTwoDigits(local.minute)}';
    return '$date $time';
  }

  void _toggleLayoutEditMode() {
    setState(() {
      _isLayoutEditMode = !_isLayoutEditMode;
    });
    if (!_isLayoutEditMode) {
      unawaited(_persistLayoutForActiveDevice());
    }
  }

  Future<void> _copyLatestSamsungTextLog() async {
    final logs = await widget.transportLogReader.readLatestSamsungLogForSharing();
    if (!mounted) {
      return;
    }
    if (logs == null || logs.trim().isEmpty) {
      _showToast('No Samsung transport log found yet.', isError: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: logs));
    if (!mounted) {
      return;
    }
    _showToast('Copied Samsung transport log to clipboard.');
  }

  void _showTransportDebugSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Debug',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (widget.onUseFakeTransportsChanged != null) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use fake transports'),
                        subtitle: Text(
                          widget.useFakeTransports
                              ? 'Fake SSDP and Samsung/Hisense transports.'
                              : 'Real SSDP and real Samsung/Hisense transports.',
                        ),
                        value: widget.useFakeTransports,
                        onChanged: (value) async {
                          await widget.onUseFakeTransportsChanged!(value);
                          setModalState(() {});
                        },
                      ),
                      Text(
                        'Compile-time default: '
                        '${widget.compileTimeUseFakeTransports ? "fake" : "real"} '
                        '(USE_FAKE_TRANSPORTS)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.copy),
                      title: const Text('Copy Samsung text logs'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        unawaited(_copyLatestSamsungTextLog());
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _resetLayoutToDefaults() {
    _layoutItems
      ..clear()
      ..addAll(buildInitialRemoteLayoutItems());
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
    setState(() {});
    _showToast('Layout reset to defaults.');
    await _persistLayoutForActiveDevice();
  }

  bool _canPlaceItem({
    required LayoutEditItem item,
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
      final overlaps =
          col < other.col + other.width &&
          col + item.width > other.col &&
          row < other.row + other.height &&
          row + item.height > other.row;
      if (overlaps) {
        return false;
      }
    }
    return true;
  }

  Widget _buildRemoteLayoutCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final cellSize = _fitCellSize(maxWidth: maxWidth, maxHeight: maxHeight);
        final gridWidth =
            (_gridColumns * cellSize) + ((_gridColumns - 1) * _gridGap);
        final gridHeight =
            (_gridRows * cellSize) + ((_gridRows - 1) * _gridGap);

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
                    child: _buildRemoteLayoutItem(
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
    final widthLimited =
        (maxWidth - ((_gridColumns - 1) * _gridGap)) / _gridColumns;
    final heightLimited =
        (maxHeight - ((_gridRows - 1) * _gridGap)) / _gridRows;
    return math.max(1, math.min(widthLimited, heightLimited));
  }

  Widget _buildRemoteLayoutItem({
    required LayoutEditItem item,
    required double cellSize,
  }) {
    final width = (item.width * cellSize) + ((item.width - 1) * _gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * _gridGap);

    final customBuilder = _customBuilderByItemId[item.id];
    if (customBuilder != null) {
      return customBuilder(item, cellSize);
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
    final customAction = _customActionByItemId[id];
    if (customAction != null) {
      return customAction;
    }
    final command = _commandByItemId[id];
    if (command == null) {
      return _noopAction;
    }
    return () => _send(command);
  }

  Widget _buildDpadItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * _gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * _gridGap);
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

  Widget _buildSearchInputItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * _gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * _gridGap);
    final definition = kRemoteLayoutItemDefinitionById[item.id];
    final keyboardIcon = definition?.icon ?? item.icon ?? Icons.keyboard_outlined;
    final canSendRemoteText =
        _activeDevice != null &&
        _activeDevice!.capabilities.contains(DeviceCapability.textInput) &&
        _remoteTextInputReady;
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: RemoteIconCircleButton(
          icon: keyboardIcon,
          onPressed: canSendRemoteText ? _openTextEntrySheet : null,
        ),
      ),
    );
  }

  void _openTextEntrySheet() {
    if (_activeDevice == null || !_remoteTextInputReady) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Send text to TV',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search or enter text',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      Navigator.pop(sheetContext);
                      unawaited(_sendText());
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      unawaited(_sendText());
                    },
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayPauseItem(LayoutEditItem item, double cellSize) {
    final appColors = AppTheme.colorsOf(context);
    final width = (item.width * cellSize) + ((item.width - 1) * _gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * _gridGap);
    final glyphSize = math.min(width, height) * 0.24;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: appColors.remoteSurface,
        borderRadius: BorderRadius.circular(height / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: () => _send(RemoteCommand.playPause),
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
    final width = (item.width * cellSize) + ((item.width - 1) * _gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * _gridGap);
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

  Widget _buildVolumeItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * _gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * _gridGap);
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

  Widget _buildPairItem(LayoutEditItem item, double cellSize) {
    final width = (item.width * cellSize) + ((item.width - 1) * _gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * _gridGap);
    final hasActiveDevice = _activeDevice != null;
    return SizedBox(
      width: width,
      height: height,
      child: RemoteIconCircleButton(
        icon: item.icon,
        label: item.label,
        onPressed: _openPairing,
        backgroundColor: hasActiveDevice
            ? Colors.green.shade600
            : AppTheme.colorsOf(context).remoteSurface,
        foregroundColor: Colors.white,
      ),
    );
  }

  static void _emptyAction() {}

  @override
  Widget build(BuildContext context) {
    final deviceName = _activeDevice?.displayName ?? 'No TV connected';

    return Scaffold(
      // Keep the remote grid fixed when the IME opens; the keyboard overlays
      // the lower portion of the screen instead of shrinking the body.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('OneRemote'),
        actions: [
          IconButton(
            onPressed: _toggleLayoutEditMode,
            icon: Icon(_isLayoutEditMode ? Icons.check : Icons.edit_outlined),
            tooltip: _isLayoutEditMode ? 'Done editing layout' : 'Edit layout',
          ),
          IconButton(
            onPressed: _showTransportDebugSheet,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Debug settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isLayoutEditMode
              ? RemoteLayoutEditor(
                  layoutItems: _layoutItems,
                  itemDefinitionsById: kRemoteLayoutItemDefinitionById,
                  gridColumns: _gridColumns,
                  gridRows: _gridRows,
                  gridGap: _gridGap,
                  onResetLayout: _resetLayoutForActiveDevice,
                  onPersistLayout: _persistLayoutForActiveDevice,
                )
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
    );
  }
}
