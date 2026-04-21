import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_repository.dart';
import 'package:one_remote/src/features/remote_control/application/layout_repository.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/src/features/remote_control/debug/runtime_flags_template_debug.dart';
import 'package:one_remote/src/features/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/src/features/remote_control/domain/models/layout_position.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/src/features/remote_control/presentation/formatting/two_digit_format.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/remote_home_actions.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/remote_keyboard_availability.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_home_app_bar_actions.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_home_remote_grid.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_home_status_panel.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_editor.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_text_entry_sheet.dart';

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
  static const String _keyboardUnavailableMessage =
      RemoteKeyboardAvailability.unavailableMessage;

  final TextEditingController _textController = TextEditingController();
  final List<LayoutEditItem> _layoutItems = buildInitialRemoteLayoutItems();
  TvDevice? _activeDevice;
  String _status = 'Ready';
  bool _isLayoutEditMode = false;
  StreamSubscription<bool>? _remoteTextReadySub;
  bool _remoteTextInputReady = false;

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
    final availability = RemoteKeyboardAvailability.evaluate(
      device: device,
      remoteTextInputReady: _remoteTextInputReady,
      requireImeReady: false,
    );
    if (!availability.isAvailable) {
      _reportKeyboardUnavailable(
        device: device,
        action: 'send',
        availability: availability,
      );
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
    final selectedDevice = await RemoteHomeActions.openPairing(
      context: context,
      commandService: widget.commandService,
      discoveryService: widget.discoveryService,
      deviceRepository: widget.deviceRepository,
      activeDeviceId: _activeDevice?.id,
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
    final time =
        '${formatTwoDigits(local.hour)}:${formatTwoDigits(local.minute)}';
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
    final didCopy = await RemoteHomeActions.copyLatestSamsungTextLog(
      transportLogReader: widget.transportLogReader,
    );
    if (!mounted) {
      return;
    }
    if (!didCopy) {
      _showToast('No Samsung transport log found yet.', isError: true);
      return;
    }
    _showToast('Copied Samsung transport log to clipboard.');
  }

  Future<void> _copyRuntimeFlagsTemplate() async {
    await RuntimeFlagsTemplateDebug.copyRuntimeFlagsTemplate(
      useFakeTransports: widget.useFakeTransports,
      activeDevice: _activeDevice,
    );
    if (!mounted) {
      return;
    }
    _showToast('Copied runtime flags template to clipboard.');
  }

  void _showTransportDebugSheet() {
    RemoteHomeActions.showTransportDebugSheet(
      context: context,
      showTransportToggle: widget.onUseFakeTransportsChanged != null,
      useFakeTransports: widget.useFakeTransports,
      compileTimeUseFakeTransports: widget.compileTimeUseFakeTransports,
      onUseFakeTransportsChanged: widget.onUseFakeTransportsChanged,
      onCopySamsungTextLogs: _copyLatestSamsungTextLog,
      onCopyRuntimeFlagsTemplate: _copyRuntimeFlagsTemplate,
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

  void _sendCommandFromGrid(RemoteCommand command) {
    unawaited(_send(command));
  }

  void _onSearchInputKeyboardPressed() {
    final device = _activeDevice;
    if (device == null) {
      setState(() {
        _status = 'No device selected.';
      });
      _showToast('No device selected.', isError: true);
      return;
    }
    final availability = RemoteKeyboardAvailability.evaluate(
      device: device,
      remoteTextInputReady: _remoteTextInputReady,
      requireImeReady: true,
    );
    if (!availability.isAvailable) {
      _reportKeyboardUnavailable(
        device: device,
        action: 'press',
        availability: availability,
      );
      return;
    }
    _openTextEntrySheet();
  }

  void _reportKeyboardUnavailable({
    required TvDevice device,
    required String action,
    required RemoteKeyboardAvailability availability,
  }) {
    setState(() => _status = _keyboardUnavailableMessage);
    _showToast(_keyboardUnavailableMessage, isError: true);
    debugPrint(availability.toDebugLog(action: action, deviceId: device.id));
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
        return RemoteTextEntrySheet(
          controller: _textController,
          onSend: () async {
            Navigator.pop(sheetContext);
            await _sendText();
          },
        );
      },
    );
  }

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
          RemoteHomeAppBarActions(
            isLayoutEditMode: _isLayoutEditMode,
            onToggleLayoutEditMode: _toggleLayoutEditMode,
            onShowDebugSettings: _showTransportDebugSheet,
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
              : RemoteHomeStatusPanel(
                  deviceName: deviceName,
                  status: _status,
                  child: RemoteHomeRemoteGrid(
                    layoutItems: _layoutItems,
                    gridColumns: _gridColumns,
                    gridRows: _gridRows,
                    gridGap: _gridGap,
                    hasActiveDevice: _activeDevice != null,
                    onSendCommand: _sendCommandFromGrid,
                    onOpenPairing: _openPairing,
                    onSearchInputPressed: _onSearchInputKeyboardPressed,
                  ),
                ),
        ),
      ),
    );
  }
}
