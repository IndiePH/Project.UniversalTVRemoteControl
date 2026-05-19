import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_remote/app/ads/bottom_banner_ad_placement.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/message_handler.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/transport_debug_settings.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/application/application.dart';
import 'package:one_remote/remote_control/debug/runtime_flags_template_debug.dart';
import 'package:one_remote/remote_control/domain/domain.dart'
    hide ConnectionState;
import 'package:one_remote/remote_control/domain/models/connection_state.dart'
    as remote_connection;
import 'package:one_remote/remote_control/presentation/pages/remote_home_actions.dart';
import 'package:one_remote/remote_control/presentation/pages/remote_keyboard_availability.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_home_app_bar_actions.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_home_remote_grid.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_home_settings_sheet.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_home_status_panel.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_text_entry_sheet.dart';
import 'package:one_remote/theme/app_theme.dart';

/// Main remote screen.
///
/// Keeps UI-focused state local and delegates command/pairing work to
/// injected services so transport and storage layers stay replaceable.
class RemoteHomePage extends StatefulWidget {
  const RemoteHomePage({
    super.key,
    required this.appEnvironment,
    required this.commandService,
    required this.deviceRepository,
    required this.discoveryService,
    required this.layoutRepository,
    required this.proEntitlementService,
    this.transportLogReaderProvider = const NoopTransportLogReaderProvider(),
  });

  final AppEnvironment appEnvironment;
  final RemoteCommandService commandService;
  final DeviceRepository deviceRepository;
  final DeviceDiscoveryService discoveryService;
  final LayoutRepository layoutRepository;
  final ProEntitlementService proEntitlementService;
  final TransportLogReaderProvider transportLogReaderProvider;

  @override
  State<RemoteHomePage> createState() => _RemoteHomePageState();
}

class _RemoteHomePageState extends State<RemoteHomePage> {
  static const bool _compileUseFakeTransports = bool.fromEnvironment(
    'USE_FAKE_TRANSPORTS',
    defaultValue: false,
  );
  static const int _gridColumns = 5;
  static const int _gridRows = 8;
  static const double _gridGap = 6;
  static const String _keyboardUnavailableMessage =
      RemoteKeyboardAvailability.unavailableMessage;

  final TextEditingController _textController = TextEditingController();
  final List<LayoutEditItem> _layoutItems = buildInitialRemoteLayoutItems();
  TvDevice? _activeDevice;
  String _status = 'Connect a TV to begin';
  bool _isLayoutEditMode = false;
  StreamSubscription<bool>? _remoteTextReadySub;
  StreamSubscription<remote_connection.ConnectionState>? _connectionStateSub;
  bool _remoteTextInputReady = false;
  remote_connection.ConnectionState _connectionState =
      remote_connection.ConnectionState.disconnected;
  bool _hasAnyPairedDevice = false;
  bool _showPairingHint = false;
  bool _pairButtonBlinkOn = false;
  Timer? _pairButtonBlinkTimer;
  Timer? _pairButtonHintResetTimer;
  OverlayEntry? _toastOverlayEntry;
  Timer? _toastOverlayTimer;

  @override
  void initState() {
    super.initState();
    widget.proEntitlementService.statusNotifier.addListener(
      _handleProEntitlementChanged,
    );
    _loadInitialDevice();
  }

  @override
  void didUpdateWidget(RemoteHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proEntitlementService != widget.proEntitlementService) {
      oldWidget.proEntitlementService.statusNotifier.removeListener(
        _handleProEntitlementChanged,
      );
      widget.proEntitlementService.statusNotifier.addListener(
        _handleProEntitlementChanged,
      );
    }
    if (oldWidget.commandService != widget.commandService) {
      _subscribeRemoteTextReady(_activeDevice);
      _subscribeConnectionState(_activeDevice);
    }
  }

  @override
  void dispose() {
    widget.proEntitlementService.statusNotifier.removeListener(
      _handleProEntitlementChanged,
    );
    _remoteTextReadySub?.cancel();
    _connectionStateSub?.cancel();
    _pairButtonBlinkTimer?.cancel();
    _pairButtonHintResetTimer?.cancel();
    _toastOverlayTimer?.cancel();
    _toastOverlayEntry?.remove();
    _textController.dispose();
    super.dispose();
  }

  void _handleProEntitlementChanged() {
    if (widget.proEntitlementService.isPro || !_isLayoutEditMode || !mounted) {
      return;
    }
    setState(() {
      _isLayoutEditMode = false;
    });
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

  void _subscribeConnectionState(TvDevice? device) {
    _connectionStateSub?.cancel();
    _connectionStateSub = null;
    if (device == null) {
      if (mounted) {
        setState(
          () =>
              _connectionState = remote_connection.ConnectionState.disconnected,
        );
      } else {
        _connectionState = remote_connection.ConnectionState.disconnected;
      }
      return;
    }
    _connectionStateSub = widget.commandService
        .watchConnectionState(device: device)
        .listen((state) {
          if (!mounted) {
            return;
          }
          setState(() => _connectionState = state);
        });
  }

  Future<void> _loadInitialDevice() async {
    final savedDevices = await widget.deviceRepository.getSavedDevices();
    final lastUsed = await widget.deviceRepository.getLastUsedDevice();
    if (!mounted) {
      return;
    }
    _hasAnyPairedDevice = savedDevices.isNotEmpty;
    if (lastUsed == null) {
      _subscribeRemoteTextReady(null);
      _subscribeConnectionState(null);
      _resetLayoutToDefaults();
      setState(() {});
      return;
    }
    setState(() {
      _activeDevice = lastUsed;
      _status = 'Ready';
    });
    _subscribeRemoteTextReady(lastUsed);
    _subscribeConnectionState(lastUsed);
    await _loadLayoutForDevice(lastUsed);
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
    final message = MessageHandler.sanitize(result);
    setState(() {
      _status = message;
    });
    if (!result.isSuccess) {
      _showToast(message, isError: true);
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
      requireImeReady: true,
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
    final message = MessageHandler.sanitize(result);
    setState(() {
      _status = message;
      if (result.isSuccess) {
        _textController.clear();
      }
    });
    if (!result.isSuccess) {
      if (result.getOutcome() == CommandOutcome.compatibility) {
        _showTextCompatibilityMessage(result.message);
      } else {
        _showToast(message, isError: true);
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
    _toastOverlayTimer?.cancel();
    _toastOverlayEntry?.remove();

    final overlay = Overlay.of(context, rootOverlay: true);
    _toastOverlayEntry = OverlayEntry(
      builder: (_) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isError
                      ? colorScheme.error
                      : colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isError
                          ? colorScheme.onError
                          : colorScheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_toastOverlayEntry!);
    _toastOverlayTimer = Timer(const Duration(seconds: 4), () {
      _toastOverlayEntry?.remove();
      _toastOverlayEntry = null;
    });
  }

  Future<void> _openPairing() async {
    _clearPairingHint();
    final selectedDevice = await RemoteHomeActions.openPairing(
      context: context,
      commandService: widget.commandService,
      discoveryService: widget.discoveryService,
      deviceRepository: widget.deviceRepository,
      activeDeviceId: _activeDevice?.id,
    );
    if (!mounted) return;

    // When a device is explicitly selected use it; otherwise re-read the last
    // used device so any rename made in the pairing screen is reflected here.
    final device =
        selectedDevice ?? await widget.deviceRepository.getLastUsedDevice();
    if (!mounted) return;
    final savedDevices = await widget.deviceRepository.getSavedDevices();
    if (!mounted) return;
    _hasAnyPairedDevice = savedDevices.isNotEmpty;
    if (device == null) {
      setState(() {
        _activeDevice = null;
        _status = 'Connect a TV to begin';
        _isLayoutEditMode = false;
      });
      _subscribeRemoteTextReady(null);
      _subscribeConnectionState(null);
      _resetLayoutToDefaults();
      if (!mounted) return;
      setState(() {});
      return;
    }

    setState(() {
      _activeDevice = device;
      _status = 'Ready';
      _showPairingHint = false;
      _pairButtonBlinkOn = false;
    });

    _subscribeRemoteTextReady(device);
    _subscribeConnectionState(device);
    await _loadLayoutForDevice(device);
  }

  void _toggleLayoutEditMode() {
    if (_activeDevice == null && !_isLayoutEditMode) {
      return;
    }
    setState(() {
      _isLayoutEditMode = !_isLayoutEditMode;
    });
    if (!_isLayoutEditMode) {
      unawaited(_persistLayoutForActiveDevice());
    }
  }

  Future<bool> _copyLatestTransportLog() async {
    final device = _activeDevice;
    final reader = device != null
        ? widget.transportLogReaderProvider.readerForDevice(device)
        : const NoopTransportLogReader();
    final didCopy = await RemoteHomeActions.copyLatestTransportLog(
      transportLogReader: reader,
    );
    if (!mounted) {
      return didCopy;
    }
    if (!didCopy) {
      _showToast('No transport log found yet.', isError: true);
      return false;
    }
    _showToast('Copied transport log to clipboard.');
    return true;
  }

  Future<void> _copyRuntimeFlagsTemplate() async {
    await RuntimeFlagsTemplateDebug.copyRuntimeFlagsTemplate(
      activeDevice: _activeDevice,
    );
    if (!mounted) {
      return;
    }
    _showToast('Copied runtime flags template to clipboard.');
  }

  Future<void> _purchasePro() async {
    final l10n = AppLocalizations.of(context)!;
    final started = await widget.proEntitlementService.purchasePro();
    if (!mounted) {
      return;
    }
    if (started) {
      _showToast(l10n.proPurchaseStarted);
    } else {
      _showToast(l10n.proStoreUnavailable, isError: true);
    }
  }

  Future<void> _restorePro() async {
    final l10n = AppLocalizations.of(context)!;
    final started = await widget.proEntitlementService.restorePurchases();
    if (!mounted) {
      return;
    }
    if (started) {
      _showToast(l10n.proRestoreStarted);
    } else {
      _showToast(l10n.proStoreUnavailable, isError: true);
    }
  }

  Future<void> _showSettingsSheet() async {
    final env = widget.appEnvironment;
    final showDebugSection = env == AppEnvironment.debug;
    final stored = await TransportDebugSettings.readUseFakeTransportsOverride();
    var pendingFake = stored ?? _compileUseFakeTransports;
    if (!mounted) {
      return;
    }
    final isDebug = env == AppEnvironment.debug;
    final proService = widget.proEntitlementService;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (_, setModalState) {
            return ValueListenableBuilder<ProEntitlementStatus>(
              valueListenable: proService.statusNotifier,
              builder: (context, status, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: proService.storeAvailableNotifier,
                  builder: (context, storeAvailable, child) {
                    return RemoteHomeSettingsSheet(
                      entitlementStatus: status,
                      storeAvailable: storeAvailable,
                      onUpgradeToPro: () => unawaited(_purchasePro()),
                      onRestorePurchases: () => unawaited(_restorePro()),
                      showDebugSection: showDebugSection,
                      showTransportToggle: isDebug,
                      useFakeTransports: pendingFake,
                      onUseFakeTransportsChanged: (value) async {
                        await TransportDebugSettings.writeUseFakeTransports(
                          value,
                        );
                        setModalState(() {
                          pendingFake = value;
                        });
                      },
                      onCopyTransportLogs: () {
                        unawaited(() async {
                          final didCopy = await _copyLatestTransportLog();
                          if (didCopy && sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        }());
                      },
                      onCopyRuntimeFlagsTemplate: () {
                        Navigator.pop(sheetContext);
                        unawaited(_copyRuntimeFlagsTemplate());
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _resetLayoutToDefaults() {
    _layoutItems
      ..clear()
      ..addAll(
        _buildLayoutDefaultsForDevice(
          _activeDevice,
          forceIncludeIds: const <String>{},
        ),
      );
  }

  Future<void> _loadLayoutForDevice(TvDevice device) async {
    final saved = await widget.layoutRepository.loadLayout(deviceId: device.id);
    _layoutItems
      ..clear()
      ..addAll(
        _buildLayoutDefaultsForDevice(
          device,
          forceIncludeIds: saved.isEmpty
              ? const <String>{}
              : saved.keys.toSet(),
        ),
      );

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

  List<LayoutEditItem> _buildLayoutDefaultsForDevice(
    TvDevice? device, {
    required Set<String> forceIncludeIds,
  }) {
    if (device == null) {
      return buildInitialRemoteLayoutItems();
    }
    final supportsTextInput = device.capabilities.contains(
      DeviceCapability.textInput,
    );
    final supportedCommands = widget.commandService.supportedCommandsFor(
      device: device,
    );
    return buildFilteredRemoteLayoutItems(
      supportedCommands: supportedCommands,
      supportsTextInput: supportsTextInput,
      forceIncludeIds: forceIncludeIds,
    );
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

  void _clearPairingHint() {
    _pairButtonBlinkTimer?.cancel();
    _pairButtonBlinkTimer = null;
    _pairButtonHintResetTimer?.cancel();
    _pairButtonHintResetTimer = null;
    if (!mounted) {
      _showPairingHint = false;
      _pairButtonBlinkOn = false;
      return;
    }
    setState(() {
      _showPairingHint = false;
      _pairButtonBlinkOn = false;
    });
  }

  void _onDisabledGridInteraction() {
    if (_activeDevice != null) {
      return;
    }
    setState(() {
      _status = 'Pair a TV first.';
      _showPairingHint = true;
      _pairButtonBlinkOn = true;
    });
    _pairButtonBlinkTimer?.cancel();
    _pairButtonBlinkTimer = Timer.periodic(const Duration(milliseconds: 700), (
      _,
    ) {
      if (!mounted || !_showPairingHint) {
        _pairButtonBlinkTimer?.cancel();
        return;
      }
      setState(() {
        _pairButtonBlinkOn = !_pairButtonBlinkOn;
      });
    });
    _pairButtonHintResetTimer?.cancel();
    _pairButtonHintResetTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted || _activeDevice != null) {
        return;
      }
      _clearPairingHint();
    });
  }

  Future<void> _onSearchInputKeyboardPressed() async {
    final device = _activeDevice;
    if (device == null) {
      setState(() {
        _status = 'No device selected.';
      });
      _showToast('No device selected.', isError: true);
      return;
    }
    final remoteTextInputReady = await widget.commandService
        .checkRemoteTextInputReady(device: device);
    if (!mounted) {
      return;
    }
    if (_remoteTextInputReady != remoteTextInputReady) {
      setState(() => _remoteTextInputReady = remoteTextInputReady);
    }
    final availability = RemoteKeyboardAvailability.evaluate(
      device: device,
      remoteTextInputReady: remoteTextInputReady,
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
    if (_activeDevice == null) {
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
    final deviceName =
        _activeDevice?.displayName ??
        AppLocalizations.of(context)!.pairingNoTvConnected;
    return ValueListenableBuilder<ProEntitlementStatus>(
      valueListenable: widget.proEntitlementService.statusNotifier,
      builder: (context, proStatus, child) {
        final isPro = proStatus == ProEntitlementStatus.entitled;
        final canToggleLayout =
            _isLayoutEditMode || (_activeDevice != null && isPro);
        final showAds = proStatus == ProEntitlementStatus.notEntitled;
        final adOverlay = BottomBannerAdPlacement.buildOverlay(
          appEnvironment: widget.appEnvironment,
          showAds: showAds,
        );

        return Scaffold(
          // Keep the remote grid fixed when the IME opens; the keyboard overlays
          // the lower portion of the screen instead of shrinking the body.
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            toolbarHeight: 50,
            title: Text(AppLocalizations.of(context)!.appTitle),
            actions: [
              RemoteHomeAppBarActions(
                isLayoutEditMode: _isLayoutEditMode,
                onToggleLayoutEditMode: canToggleLayout
                    ? _toggleLayoutEditMode
                    : null,
                onShowSettings: () => unawaited(_showSettingsSheet()),
                isPro: isPro,
              ),
            ],
            flexibleSpace: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 1,
                  color: AppTheme.colorsOf(
                    context,
                  ).remoteOutline.withValues(alpha: 0.25),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: AppTheme.colorsOf(
                  context,
                ).remoteOutline.withValues(alpha: 0.25),
              ),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
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
                          connectionState: _connectionState,
                          onOpenPairing: _openPairing,
                          hasActiveDevice: _activeDevice != null,
                          hasAnyPairedDevice: _hasAnyPairedDevice,
                          highlightPairButton: _showPairingHint,
                          pairButtonBlinkOn: _pairButtonBlinkOn,
                          overlayOnChild: false,
                          child: RemoteHomeRemoteGrid(
                            layoutItems: _layoutItems,
                            gridColumns: _gridColumns,
                            gridRows: _gridRows,
                            gridGap: _gridGap,
                            controlsEnabled: _activeDevice != null,
                            pairingHintActive:
                                _showPairingHint && _activeDevice == null,
                            onSendCommand: _sendCommandFromGrid,
                            onSearchInputPressed: () =>
                                unawaited(_onSearchInputKeyboardPressed()),
                            onDisabledInteraction: _onDisabledGridInteraction,
                          ),
                        ),
                ),
              ),
              ...[adOverlay].whereType<Widget>(),
            ],
          ),
        );
      },
    );
  }
}
