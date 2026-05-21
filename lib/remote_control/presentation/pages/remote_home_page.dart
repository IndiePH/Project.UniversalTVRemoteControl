import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/ads/interstitial_ad_controller.dart';
import 'package:one_remote/app/ads/bottom_banner_ad_placement.dart';
import 'package:one_remote/app/compliance/ad_consent_coordinator.dart';
import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/app/compliance/app_legal_urls.dart';
import 'package:one_remote/app/compliance/legal_link_launcher.dart';
import 'package:one_remote/app/feedback/feedback_payload.dart';
import 'package:one_remote/app/feedback/feedback_submission_result.dart';
import 'package:one_remote/app/feedback/feedback_submission_sheet.dart';
import 'package:one_remote/app/feedback/feedback_submission_service.dart';
import 'package:one_remote/app/package_info/app_package_info_source.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/message_handler.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/theme/app_theme_controller.dart';
import 'package:one_remote/app/theme/app_theme_preference.dart';
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
import 'package:one_remote/remote_control/presentation/widgets/remote_home_device_switcher_sheet.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_home_status_panel.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_grid_metrics.dart';
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
    required this.interstitialAdController,
    required this.commandService,
    required this.deviceRepository,
    required this.discoveryService,
    required this.layoutRepository,
    required this.proEntitlementService,
    this.transportLogReaderProvider = const NoopTransportLogReaderProvider(),
  });

  final AppEnvironment appEnvironment;
  final InterstitialAdController interstitialAdController;
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
  bool _deviceSwitcherSheetOpen = false;
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
    _syncInterstitialWarmUp();
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
      _syncInterstitialWarmUp();
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

  bool get _isResolvedFreeTier =>
      widget.proEntitlementService.statusNotifier.value ==
      ProEntitlementStatus.notEntitled;

  void _handleProEntitlementChanged() {
    _syncInterstitialWarmUp();
    if (!mounted) {
      return;
    }
    if (!widget.proEntitlementService.isPro && _isLayoutEditMode) {
      setState(() => _isLayoutEditMode = false);
    }
    if (_isResolvedFreeTier) {
      unawaited(_refreshSavedDevicesForFreeTier());
      return;
    }
    final device = _activeDevice;
    if (device != null) {
      unawaited(_loadLayoutForDevice(device));
    }
  }

  Future<void> _refreshSavedDevicesForFreeTier() async {
    var savedDevices = await widget.deviceRepository.getSavedDevices();
    final removedExtraDevices =
        await FreeTierSavedDeviceCleanup.removeNonActiveSavedDevices(
          isFreeTier: _isResolvedFreeTier,
          activeDeviceId: _activeDevice?.id,
          savedDevices: savedDevices,
          commandService: widget.commandService,
          deviceRepository: widget.deviceRepository,
        );
    if (removedExtraDevices) {
      savedDevices = await widget.deviceRepository.getSavedDevices();
    }
    if (!mounted) {
      return;
    }

    final shouldReopenDeviceSwitcher = _deviceSwitcherSheetOpen;
    if (shouldReopenDeviceSwitcher && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      _deviceSwitcherSheetOpen = false;
    }

    _hasAnyPairedDevice = savedDevices.isNotEmpty;
    final lastUsed = await widget.deviceRepository.getLastUsedDevice();
    if (!mounted) {
      return;
    }

    if (lastUsed == null) {
      setState(() {
        _activeDevice = null;
        _status = 'Connect a TV to begin';
        _isLayoutEditMode = false;
      });
      _subscribeRemoteTextReady(null);
      _subscribeConnectionState(null);
      _resetLayoutToDefaults();
    } else if (_activeDevice?.id != lastUsed.id) {
      await _activateDevice(lastUsed);
    } else if (removedExtraDevices) {
      setState(() {});
    }

    if (!mounted) {
      return;
    }
    final device = _activeDevice;
    if (device != null) {
      await _loadLayoutForDevice(device);
    }
    if (!mounted) {
      return;
    }
    if (shouldReopenDeviceSwitcher && _hasAnyPairedDevice) {
      unawaited(_showDeviceSwitcher());
    }
  }

  void _syncInterstitialWarmUp() {
    final showAds =
        widget.proEntitlementService.statusNotifier.value ==
        ProEntitlementStatus.notEntitled;
    widget.interstitialAdController.warmUp(
      showAds: showAds,
      canRequestAds: AdConsentCoordinator.canRequestAds,
    );
  }

  Future<void> _toggleProEntitlementForTesting() async {
    await widget.proEntitlementService.debugToggleEntitlement();
  }

  Future<void> _triggerInterstitialTestAd() async {
    const showAds = true;
    final canRequestAds = AdConsentCoordinator.canRequestAds;
    widget.interstitialAdController.warmUp(
      showAds: showAds,
      canRequestAds: canRequestAds,
    );
    await widget.interstitialAdController.showForTesting(
      context: context,
      showAds: showAds,
      canRequestAds: canRequestAds,
    );
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
          setState(() {
            _connectionState = state;
            if (_activeDevice == null) {
              return;
            }
            if (state == remote_connection.ConnectionState.connected &&
                _status == 'Disconnected') {
              _status = 'Ready';
            } else if (state ==
                    remote_connection.ConnectionState.disconnected &&
                _status == 'Ready') {
              _status = 'Disconnected';
            }
          });
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
      return false;
    }
    final showAds =
        widget.proEntitlementService.statusNotifier.value ==
        ProEntitlementStatus.notEntitled;
    final canRequestAds = AdConsentCoordinator.canRequestAds;
    widget.interstitialAdController.recordSuccessfulAction(
      showAds: showAds,
      canRequestAds: canRequestAds,
    );
    unawaited(
      widget.interstitialAdController.maybeShow(
        context: context,
        showAds: showAds,
        canRequestAds: canRequestAds,
        isLayoutEditMode: _isLayoutEditMode,
        isModalOpen: ModalRoute.of(context)?.isCurrent != true,
      ),
    );
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

  Future<void> _activateDevice(TvDevice device) async {
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

  void _showProDeviceSwitchLockedMessage() {
    final l10n = AppLocalizations.of(context)!;
    _showToast(l10n.proDeviceSwitchLockedMessage, isError: false);
  }

  void _showProLayoutLockedMessage() {
    final l10n = AppLocalizations.of(context)!;
    _showToast(l10n.proLayoutLockedTooltip, isError: false);
  }

  bool _canSwitchToPairedDevice(TvDevice device) {
    if (widget.proEntitlementService.isPro) {
      return true;
    }
    final activeId = _activeDevice?.id;
    return activeId == null || activeId == device.id;
  }

  List<TvDevice> _devicesForSwitcherDisplay(List<TvDevice> savedDevices) {
    final activeId = _activeDevice?.id;
    if (activeId == null) {
      return savedDevices;
    }
    final activeIndex = savedDevices.indexWhere(
      (device) => device.id == activeId,
    );
    if (activeIndex <= 0) {
      return savedDevices;
    }
    return [
      savedDevices[activeIndex],
      ...savedDevices.take(activeIndex),
      ...savedDevices.skip(activeIndex + 1),
    ];
  }

  Future<void> _showDeviceSwitcher() async {
    if (!_hasAnyPairedDevice) {
      await _openPairing();
      return;
    }
    final savedDevices = await widget.deviceRepository.getSavedDevices();
    if (!mounted || savedDevices.isEmpty) {
      return;
    }
    final canSwitchDevices = widget.proEntitlementService.isPro;
    _deviceSwitcherSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return RemoteHomeDeviceSwitcherSheet(
          devices: _devicesForSwitcherDisplay(savedDevices),
          activeDeviceId: _activeDevice?.id,
          canSwitchDevices: canSwitchDevices,
          onDeviceSelected: (device) {
            if (!_canSwitchToPairedDevice(device)) {
              _showProDeviceSwitchLockedMessage();
              return;
            }
            Navigator.pop(sheetContext);
            unawaited(() async {
              await widget.deviceRepository.setLastUsedDevice(device.id);
              if (!mounted) {
                return;
              }
              await _activateDevice(device);
            }());
          },
          onSwitchBlocked: _showProDeviceSwitchLockedMessage,
          onManageDevices: () {
            Navigator.pop(sheetContext);
            unawaited(_openPairing());
          },
        );
      },
    );
    _deviceSwitcherSheetOpen = false;
  }

  Future<void> _openPairing() async {
    _clearPairingHint();
    final selectedDevice = await RemoteHomeActions.openPairing(
      context: context,
      commandService: widget.commandService,
      discoveryService: widget.discoveryService,
      deviceRepository: widget.deviceRepository,
      proEntitlementService: widget.proEntitlementService,
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

    await _activateDevice(device);
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

  Future<bool> _copyDiagnosticsReport() async {
    return RemoteHomeActions.copyDiagnosticsReport(
      recorder: GetIt.instance<AppDiagnosticsRecorder>(),
    );
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

  Future<void> _showFeedbackSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final submissionService = GetIt.instance<FeedbackSubmissionService>();
    final packageInfo =
        await GetIt.instance<AppPackageInfoSource>().getPackageInfo();
    if (!mounted) {
      return;
    }
    final platform = defaultTargetPlatform.name;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FeedbackSubmissionSheet(
          onSubmit: ({required message, required category}) async {
            final result = await submissionService.submit(
              FeedbackPayload(
                message: message,
                category: category,
                platform: platform,
                appVersion: packageInfo.versionLabel,
                submittedAtUtc: DateTime.now().toUtc(),
              ),
            );
            if (!mounted) {
              return FeedbackSheetSubmitOutcome.failed;
            }
            if (result.isSuccess) {
              return FeedbackSheetSubmitOutcome.success;
            }
            switch (result.outcome) {
              case FeedbackSubmissionOutcome.emptyMessage:
                _showToast(l10n.feedbackMessageTooShort, isError: true);
                return FeedbackSheetSubmitOutcome.empty;
              case FeedbackSubmissionOutcome.notConfigured:
                _showToast(l10n.feedbackNotConfigured, isError: true);
                return FeedbackSheetSubmitOutcome.notConfigured;
              case FeedbackSubmissionOutcome.networkError:
                _showToast(l10n.feedbackSendFailed, isError: true);
                return FeedbackSheetSubmitOutcome.failed;
              case FeedbackSubmissionOutcome.success:
                return FeedbackSheetSubmitOutcome.success;
            }
          },
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (sent == true) {
      _showToast(l10n.feedbackSent);
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext sheetContext) async {
    final l10n = AppLocalizations.of(context)!;
    final opened = await LegalLinkLauncher.openUrl(
      AppLegalUrls.privacyPolicyUrl,
    );
    if (!mounted) {
      return;
    }
    if (!opened) {
      _showToast(l10n.settingsLegalLinkFailed, isError: true);
    }
  }

  Future<void> _openAdPrivacyOptions(BuildContext sheetContext) async {
    await AdConsentCoordinator.showPrivacyOptionsForm();
    if (sheetContext.mounted) {
      Navigator.pop(sheetContext);
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
    final showAdPrivacyOptions =
        await AdConsentCoordinator.isPrivacyOptionsRequired();
    if (!mounted) {
      return;
    }
    final isDebug = env == AppEnvironment.debug;
    final proService = widget.proEntitlementService;
    final showPrivacyPolicyLink = AppLegalUrls.hasPrivacyPolicyUrl;
    final themeController = GetIt.instance<AppThemeController>();

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
                    return ValueListenableBuilder<AppThemePreference>(
                      valueListenable: themeController.preferenceNotifier,
                      builder: (context, themePreference, child) {
                        return RemoteHomeSettingsSheet(
                          entitlementStatus: status,
                          storeAvailable: storeAvailable,
                          themePreference: themePreference,
                          onThemePreferenceChanged: (value) =>
                              unawaited(themeController.setPreference(value)),
                          onUpgradeToPro: () => unawaited(_purchasePro()),
                          onRestorePurchases: () => unawaited(_restorePro()),
                          showDebugSection: showDebugSection,
                          diagnosticsRecorder:
                              GetIt.instance<AppDiagnosticsRecorder>(),
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
                          onCopyDiagnosticsReport: () {
                            unawaited(() async {
                              final didCopy = await _copyDiagnosticsReport();
                              if (didCopy && sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            }());
                          },
                          onCopyRuntimeFlagsTemplate: () {
                            Navigator.pop(sheetContext);
                            unawaited(_copyRuntimeFlagsTemplate());
                          },
                          onOpenFeedback: () {
                            Navigator.pop(sheetContext);
                            unawaited(_showFeedbackSheet());
                          },
                          showPrivacyPolicyLink: showPrivacyPolicyLink,
                          onOpenPrivacyPolicy: () =>
                              unawaited(_openPrivacyPolicy(sheetContext)),
                          showAdPrivacyOptions: showAdPrivacyOptions,
                          onOpenAdPrivacyOptions: () =>
                              unawaited(_openAdPrivacyOptions(sheetContext)),
                        );
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
    final isPro = widget.proEntitlementService.isPro;
    final saved = isPro
        ? await widget.layoutRepository.loadLayout(deviceId: device.id)
        : const <String, LayoutPosition>{};
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

    if (isPro) {
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
    if (col + item.width > kRemoteLayoutGridColumns ||
        row + item.height > kRemoteLayoutGridRows) {
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
        final showLayoutLockedOnPress =
            !canToggleLayout && _activeDevice != null && !isPro;
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
                    : showLayoutLockedOnPress
                    ? _showProLayoutLockedMessage
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
                          gridColumns: kRemoteLayoutGridColumns,
                          gridRows: kRemoteLayoutGridRows,
                          gridGap: kRemoteLayoutGridGap,
                          onResetLayout: _resetLayoutForActiveDevice,
                          onPersistLayout: _persistLayoutForActiveDevice,
                        )
                      : RemoteHomeStatusPanel(
                          deviceName: deviceName,
                          status: _status,
                          connectionState: _connectionState,
                          onOpenPairing: _openPairing,
                          onOpenDeviceSwitcher: _hasAnyPairedDevice
                              ? _showDeviceSwitcher
                              : null,
                          hasActiveDevice: _activeDevice != null,
                          hasAnyPairedDevice: _hasAnyPairedDevice,
                          highlightPairButton: _showPairingHint,
                          pairButtonBlinkOn: _pairButtonBlinkOn,
                          overlayOnChild: false,
                          child: RemoteHomeRemoteGrid(
                            layoutItems: _layoutItems,
                            gridColumns: kRemoteLayoutGridColumns,
                            gridRows: kRemoteLayoutGridRows,
                            gridGap: kRemoteLayoutGridGap,
                            controlsEnabled:
                                _activeDevice != null &&
                                _connectionState ==
                                    remote_connection.ConnectionState.connected,
                            pairingHintActive:
                                _showPairingHint && _activeDevice == null,
                            onSendCommand: _sendCommandFromGrid,
                            onSearchInputPressed: () =>
                                unawaited(_onSearchInputKeyboardPressed()),
                            onDisabledInteraction: _onDisabledGridInteraction,
                            onInterstitialTestPressed: () =>
                                unawaited(_triggerInterstitialTestAd()),
                            onProToggleTestPressed: () =>
                                unawaited(_toggleProEntitlementForTesting()),
                            proToggleTestIsPro: isPro,
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
