import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/data/manual_add_variant_probe.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/application/application.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_coordinator.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_data.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_dialogs.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_pairing_page_metrics.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_view_state.dart';
import 'package:one_remote/remote_control/presentation/widgets/pairing_page_sections.dart';

/// Pairing flow entry point.
///
/// This screen supports three lightweight paths:
/// - quick reconnect via saved devices,
/// - fake scan/discovery list (swap with real discovery later),
/// - manual brand + IP fallback.
class PairingPage extends StatefulWidget {
  const PairingPage({
    super.key,
    required this.commandService,
    required this.discoveryService,
    required this.deviceRepository,
    required this.stepsRegistry,
    required this.hintRegistry,
    required this.reachabilityService,
    required this.proEntitlementService,
    this.activeDeviceId,
    this.identityRegistry,
    this.layoutRepository,
    this.manualAddVariantProbe,
  });

  final RemoteCommandService commandService;
  final DeviceDiscoveryService discoveryService;
  final DeviceRepository deviceRepository;
  final PrePairingStepsRegistry stepsRegistry;
  final PairingProgressHintRegistry hintRegistry;
  final TvReachabilityService reachabilityService;
  final ProEntitlementService proEntitlementService;
  final String? activeDeviceId;

  /// Optional variant probe for manual add-by-IP (see `ManualAddVariantProbe`).
  /// Null (e.g. in unit tests) falls back to the default variant — safe
  /// because in production this is always provided, and every brand except
  /// Sony resolves to its one known variant via the probe's own
  /// single-candidate short-circuit (no I/O) anyway.
  final ManualAddVariantProbe? manualAddVariantProbe;

  /// Optional identity registry. When wired, discovery reconciles saved
  /// devices to discovered ones by stable id and persists refreshed hosts so
  /// a paired TV survives an IP change. Null (e.g. in unit tests) skips
  /// reconciliation and degrades to legacy IP-derived behaviour.
  final DeviceIdentityRegistry? identityRegistry;
  final LayoutRepository? layoutRepository;

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  PairingPageViewState _viewState = const PairingPageViewState();
  TvDevice? _activePairingDevice;
  bool _legacyCleanupOffered = false;
  final ScrollController _pairedDevicesScrollController = ScrollController();
  late final PairingPageCoordinator _pairingCoordinator =
      PairingPageCoordinator(
        commandService: widget.commandService,
        deviceRepository: widget.deviceRepository,
        diagnosticsRecorder:
            GetIt.instance.isRegistered<AppDiagnosticsRecorder>()
            ? GetIt.instance<AppDiagnosticsRecorder>()
            : null,
      );

  @override
  void dispose() {
    widget.proEntitlementService.statusNotifier.removeListener(
      _handleProEntitlementChanged,
    );
    _pairedDevicesScrollController.dispose();
    super.dispose();
  }

  void _showPairingSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    widget.proEntitlementService.statusNotifier.addListener(
      _handleProEntitlementChanged,
    );
    _scanDevices();
    _loadRecentManualIps();
    _loadPairingMetadata(refreshDiscoveryAfterCleanup: true);
  }

  void _handleProEntitlementChanged() {
    if (!_isResolvedFreeTier) {
      return;
    }
    unawaited(_loadPairingMetadata(refreshDiscoveryAfterCleanup: true));
  }

  bool get _isResolvedFreeTier =>
      FreeTierDevicePolicy.isFreeTierFrom(widget.proEntitlementService);

  Future<void> _loadRecentManualIps() async {
    final ips = await PairingPageData.loadRecentManualIps(
      widget.deviceRepository,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _viewState = _viewState.copyWith(recentManualIps: ips);
    });
  }

  Future<void> _loadPairingMetadata({
    bool refreshDiscoveryAfterCleanup = false,
  }) async {
    var metadata = await PairingPageData.loadPairingMetadata(
      widget.deviceRepository,
    );
    final cleanupOutcome = await FreeTierDevicePolicy.cleanupExtraSavedDevices(
      isFreeTier: _isResolvedFreeTier,
      activeDeviceId: widget.activeDeviceId,
      savedDevices: metadata.savedDevices,
      commandService: widget.commandService,
      deviceRepository: widget.deviceRepository,
      layoutRepository: widget.layoutRepository,
    );
    final removedExtraDevices = cleanupOutcome.removed;
    if (removedExtraDevices) {
      metadata = await PairingPageData.loadPairingMetadata(
        widget.deviceRepository,
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _viewState = _viewState.copyWith(
        savedDevices: metadata.savedDevices,
        savedDeviceIds: metadata.savedDeviceIds,
        pairingHistoryByDeviceId: metadata.pairingHistoryByDeviceId,
      );
    });
    if (removedExtraDevices && refreshDiscoveryAfterCleanup) {
      unawaited(_scanDevices());
    }
  }

  Future<void> _scanDevices() async {
    setState(() {
      _viewState = _viewState.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        discoveredDevices: const [],
        scanCount: _viewState.scanCount + 1,
      );
    });

    try {
      final discovered = await PairingPageData.discoverDevices(
        widget.discoveryService,
      );
      if (!mounted) {
        return;
      }
      // Reconcile discovered ↔ saved by stable id and persist any host
      // changes so a paired TV that moved IPs keeps working. Best-effort,
      // fire-and-forget: the scan result is shown immediately regardless.
      var saved = _viewState.savedDevices;
      try {
        saved = await widget.deviceRepository.getSavedDevices();
      } catch (_) {
        // Discovery remains useful even if saved-device refresh is unavailable.
      }
      var staleLegacyDevices = const <TvDevice>[];
      final lastSeenRepository =
          widget.deviceRepository is DeviceLastSeenRepository
          ? widget.deviceRepository as DeviceLastSeenRepository
          : null;
      if (lastSeenRepository != null && saved.isNotEmpty) {
        try {
          staleLegacyDevices =
              await LegacyDeviceOrphanDetector.updateAndFindCandidates(
                savedDevices: saved,
                discoveredDevices: discovered,
                activeDeviceId: widget.activeDeviceId,
                repository: lastSeenRepository,
              );
        } catch (_) {
          // Orphan tracking is advisory and must not block discovery.
        }
      }
      if (saved.isNotEmpty) {
        unawaited(
          PairingPageData.reconcileDiscovery(
            discovered: discovered,
            saved: saved,
            identityRegistry: widget.identityRegistry,
            deviceRepository: widget.deviceRepository,
            layoutRepository: widget.layoutRepository,
          ),
        );
      }
      setState(() {
        _viewState = _viewState.copyWith(discoveredDevices: discovered);
      });
      if (staleLegacyDevices.isNotEmpty &&
          widget.proEntitlementService.isPro &&
          !_legacyCleanupOffered) {
        _legacyCleanupOffered = true;
        unawaited(_offerLegacyCleanup(staleLegacyDevices));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _viewState = _viewState.copyWith(
          errorMessage: AppLocalizations.of(context)!.pairingDiscoveryFailed,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _viewState = _viewState.copyWith(isLoading: false);
        });
      }
    }
  }

  Future<void> _selectPairedDevice(TvDevice device) async {
    if (device.id == widget.activeDeviceId) {
      _showPairingSnackBar(
        AppLocalizations.of(
          context,
        )!.pairingAlreadyUsingDevice(device.displayName),
      );
      return;
    }
    final persisted = await TvDeviceSelection.tryPersistLastUsed(
      device: device,
      activeDeviceId: widget.activeDeviceId,
      isPro: widget.proEntitlementService.isPro,
      deviceRepository: widget.deviceRepository,
    );
    if (!persisted) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.proDeviceSwitchLockedMessage,
          ),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(device);
  }

  Future<void> _selectDevice(TvDevice device) async {
    if (_viewState.savedDeviceIds.contains(device.id)) {
      _showPairingSnackBar(
        AppLocalizations.of(
          context,
        )!.pairingDeviceAlreadyPaired(device.displayName),
      );
      return;
    }
    final steps = widget.stepsRegistry.stepsFor(
      device.brand,
      device.protocolVariant,
    );
    if (steps != null) {
      if (!mounted) return;
      final confirmed = await PairingPageDialogs.confirmPrePairing(
        context: context,
        brandName: device.brand.displayName,
        steps: steps,
      );
      if (!confirmed || !mounted) return;
    }
    await _pairSelectedDevice(device: device);
  }

  Future<void> _replaceActivePairedDeviceForFreeTier(TvDevice newDevice) async {
    final replaced =
        await FreeTierDevicePolicy.replaceActiveDeviceBeforePairingWhenNotPro(
          isPro: widget.proEntitlementService.isPro,
          activeDeviceId: widget.activeDeviceId,
          newDevice: newDevice,
          savedDevices: _viewState.savedDevices,
          commandService: widget.commandService,
          deviceRepository: widget.deviceRepository,
          layoutRepository: widget.layoutRepository,
        );
    if (replaced) {
      await _loadPairingMetadata();
    }
  }

  Future<void> _pairSelectedDevice({
    required TvDevice device,
    String? manualIpToSave,
  }) async {
    if (_viewState.isPairingInProgress) {
      return;
    }
    await _replaceActivePairedDeviceForFreeTier(device);
    if (!mounted) {
      return;
    }
    _activePairingDevice = device;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _viewState = _viewState.copyWith(
        isPairingInProgress: true,
        pairingHint: widget.hintRegistry.hintFor(
          device.brand,
          device.protocolVariant,
        ),
        clearErrorMessage: true,
      );
    });

    PairingAttemptResult? result;
    String? exceptionMessage;

    try {
      result = await _pairingCoordinator.pairSelectedDevice(
        device: device,
        manualIpToSave: manualIpToSave,
        promptPin: (pairingMessage, pinFormat) async {
          if (mounted) {
            setState(() {
              _viewState = _viewState.copyWith(isPairingInProgress: false);
            });
          }
          final pin = await PairingPageDialogs.promptPairingPin(
            context: context,
            pairingMessage: pairingMessage,
            pinFormat: pinFormat,
          );
          if (mounted) {
            setState(() {
              _viewState = _viewState.copyWith(isPairingInProgress: true);
            });
          }
          return pin;
        },
        onPinRejected: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          setState(() {
            _viewState = _viewState.copyWith(isPairingInProgress: false);
          });
        },
      );
    } catch (_) {
      exceptionMessage = l10n.pairingExceptionFailed;
    } finally {
      _activePairingDevice = null;
      if (mounted) {
        setState(() {
          _viewState = _viewState.copyWith(
            isPairingInProgress: false,
            clearPairingHint: true,
          );
        });
      }
    }

    if (!mounted) return;

    if (exceptionMessage != null) {
      setState(() {
        _viewState = _viewState.copyWith(errorMessage: exceptionMessage);
      });
      await PairingPageDialogs.showPairingOutcome(
        context: context,
        isSuccess: false,
        deviceName: device.displayName,
        errorMessage: exceptionMessage,
      );
      return;
    }

    if (!result!.isSuccess) {
      final errorMsg = result.message;
      setState(() {
        _viewState = _viewState.copyWith(errorMessage: errorMsg);
      });
      await PairingPageDialogs.showPairingOutcome(
        context: context,
        isSuccess: false,
        deviceName: device.displayName,
        errorMessage: errorMsg,
      );
      return;
    }

    await PairingPageDialogs.showPairingOutcome(
      context: context,
      isSuccess: true,
      deviceName: device.displayName,
    );
    if (!mounted) return;
    Navigator.of(context).pop(device);
  }

  Future<void> _confirmRemoveSavedDevice(TvDevice device) async {
    final isActiveDevice = widget.activeDeviceId == device.id;
    final shouldRemove = await PairingPageDialogs.confirmRemoveSavedDevice(
      context: context,
      device: device,
      isActiveDevice: isActiveDevice,
    );
    if (!shouldRemove) {
      return;
    }
    if (!mounted) {
      return;
    }

    await widget.commandService.unpairDevice(device: device);
    await widget.deviceRepository.removeSavedDevice(device.id);
    final layoutDeleter = widget.layoutRepository is LayoutDeletionRepository
        ? widget.layoutRepository as LayoutDeletionRepository
        : null;
    try {
      await layoutDeleter?.deleteLayout(deviceId: device.id);
    } catch (_) {
      // Keep the saved-device removal complete if layout cleanup fails.
    }
    await _loadPairingMetadata();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          )!.pairingDeviceRemoved(device.displayName),
        ),
      ),
    );
  }

  Future<void> _offerLegacyCleanup(List<TvDevice> devices) async {
    if (!mounted) return;
    final shouldRemove = await PairingPageDialogs.confirmRemoveLegacyDevices(
      context: context,
      devices: devices,
    );
    if (!shouldRemove || !mounted) return;

    var removedAny = false;
    final layoutDeleter = widget.layoutRepository is LayoutDeletionRepository
        ? widget.layoutRepository as LayoutDeletionRepository
        : null;
    for (final device in devices) {
      try {
        await widget.commandService.unpairDevice(device: device);
      } catch (_) {
        // Continue with local cleanup when the TV is no longer reachable.
      }
      try {
        await widget.deviceRepository.removeSavedDevice(device.id);
        removedAny = true;
      } catch (_) {
        continue;
      }
      if (layoutDeleter != null) {
        try {
          await layoutDeleter.deleteLayout(deviceId: device.id);
        } catch (_) {
          // A failed layout cleanup leaves the saved layout recoverable.
        }
      }
    }

    if (!removedAny) return;
    await _loadPairingMetadata();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.pairingLegacyDevicesRemoved,
        ),
      ),
    );
  }

  Future<void> _renameDevice(TvDevice device) async {
    final newName = await PairingPageDialogs.promptRenameDevice(
      context: context,
      currentName: device.displayName,
    );
    if (newName == null || !mounted) return;
    await widget.deviceRepository.saveDevice(
      device.copyWith(displayName: newName),
    );
    await _loadPairingMetadata();
  }

  Future<void> _addManualDevice({
    required TvBrand brand,
    required String ip,
  }) async {
    final variant =
        await widget.manualAddVariantProbe?.resolve(brand: brand, host: ip) ??
        _fallbackVariantWithoutProbe(brand);
    final device = PairingPageData.buildManualDevice(
      brand: brand,
      ip: ip,
      protocolVariant: variant,
    );
    await _pairSelectedDevice(device: device, manualIpToSave: ip);
  }

  /// Used only when [PairingPage.manualAddVariantProbe] is null (e.g. a test
  /// that doesn't wire one). Must mirror what `DefaultManualAddVariantProbe`
  /// would resolve to for each brand's actually-registered default adapter —
  /// not just return `TvDevice.defaultProtocolVariant` unconditionally,
  /// since `_adapterFor` does a direct, no-fallback `(brand, variant)` map
  /// lookup: a wrong variant string here means "no adapter found," not a
  /// harmless default. Today only TCL's registered adapter
  /// (`TclLegacyWifiAdapter`) uses a non-default variant string; every other
  /// brand's default adapter already uses `TvDevice.defaultProtocolVariant`
  /// itself, so no other case is needed here.
  String _fallbackVariantWithoutProbe(TvBrand brand) => switch (brand) {
    TvBrand.tcl => TclProtocolVariants.legacyWifi,
    _ => TvDevice.defaultProtocolVariant,
  };

  void _showManualAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PairingManualAddSheet(
        recentManualIps: _viewState.recentManualIps,
        onAdd: (brand, ip) => _addManualDevice(brand: brand, ip: ip),
      ),
    );
  }

  void _showPairingHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: const PairingTroubleshootingGuidanceSection(),
          ),
        );
      },
    );
  }

  Widget _buildFabs() {
    final disabled = _viewState.isPairingInProgress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'fab_manual',
          tooltip: AppLocalizations.of(context)!.pairingAddManuallyTooltip,
          onPressed: disabled ? null : _showManualAddSheet,
          child: const Icon(Icons.keyboard),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'fab_scan',
          tooltip: AppLocalizations.of(context)!.pairingScanTooltip,
          onPressed: disabled ? null : _scanDevices,
          child: const Icon(Icons.search),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _viewState.isPairingInProgress) {
          unawaited(
            _pairingCoordinator.cancelPairing(device: _activePairingDevice!),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.pairingSelectRemoteTitle),
          automaticallyImplyLeading: true,
          actions: [
            IconButton(
              tooltip: AppLocalizations.of(context)!.pairingHelpTooltip,
              icon: const Icon(Icons.help_outline),
              onPressed: _viewState.isPairingInProgress
                  ? null
                  : _showPairingHelp,
            ),
          ],
        ),
        floatingActionButton: _buildFabs(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _viewState.isPairingInProgress,
              child: _buildScrollBody(),
            ),
            PairingBusyOverlay(
              visible: _viewState.isPairingInProgress,
              hint: _viewState.pairingHint,
            ),
          ],
        ),
      ),
    );
  }

  /// Saved TVs under **Paired** — active TV first, then remaining save order.
  List<TvDevice> _pairedDevicesForDisplay() {
    return SavedDeviceDisplayOrdering.activeFirst(
      savedDevices: _viewState.savedDevices,
      activeDeviceId: widget.activeDeviceId,
    );
  }

  Widget _buildPairedDeviceList(List<TvDevice> pairedDevices) {
    const maxVisible = RemotePairingPageMetrics.maxVisiblePairedDevices;
    const rowExtent = RemotePairingPageMetrics.pairedListRowExtent;
    final needsBoundedViewport = pairedDevices.length > maxVisible;
    final activeDeviceId = widget.activeDeviceId;
    final isPro = widget.proEntitlementService.isPro;
    final l10n = AppLocalizations.of(context)!;

    final listView = ListView.builder(
      key: const Key('pairing_paired_devices_list'),
      controller: needsBoundedViewport ? _pairedDevicesScrollController : null,
      shrinkWrap: !needsBoundedViewport,
      physics: needsBoundedViewport
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemExtent: rowExtent,
      itemCount: pairedDevices.length,
      itemBuilder: (context, index) {
        final device = pairedDevices[index];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical:
                RemotePairingPageMetrics.pairedListItemVerticalPadding / 2,
          ),
          child: PairedTvListItem(
            key: ValueKey('${device.id}_${_viewState.scanCount}'),
            device: device,
            pairedAt: _viewState.pairingHistoryByDeviceId[device.id],
            isActive: device.id == activeDeviceId,
            switchLocked: ProDeviceSwitchPolicy.isSwitchLocked(
              device: device,
              activeDeviceId: activeDeviceId,
              isPro: isPro,
            ),
            switchLockTooltip: l10n.proDeviceSwitchLockedTooltip,
            reachabilityService: widget.reachabilityService,
            onConfirmDismiss: (_) async {
              await _confirmRemoveSavedDevice(device);
              return false;
            },
            onRename: () => unawaited(_renameDevice(device)),
            onInfo: () => unawaited(
              PairingPageDialogs.showDeviceInfo(
                context: context,
                device: device,
                pairedAt: _viewState.pairingHistoryByDeviceId[device.id],
              ),
            ),
            onTap: () => unawaited(_selectPairedDevice(device)),
          ),
        );
      },
    );

    if (!needsBoundedViewport) {
      return listView;
    }
    return SizedBox(
      height: maxVisible * rowExtent,
      child: Scrollbar(
        thumbVisibility: true,
        controller: _pairedDevicesScrollController,
        child: listView,
      ),
    );
  }

  Widget _buildScrollBody() {
    final pairedDevices = _pairedDevicesForDisplay();
    final l10n = AppLocalizations.of(context)!;
    return CustomScrollView(
      slivers: [
        if (pairedDevices.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: RemoteSelectionSectionHeader(l10n.pairingSectionPaired),
            ),
          ),
          SliverToBoxAdapter(child: _buildPairedDeviceList(pairedDevices)),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: RemoteSelectionSectionHeader(l10n.pairingSectionAvailable),
          ),
        ),
        if (_viewState.errorMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _viewState.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        if (_viewState.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_viewState.discoveredDevices.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  AppLocalizations.of(context)!.pairingNoDevicesFound,
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: _viewState.discoveredDevices.length,
            itemBuilder: (context, index) {
              final device = _viewState.discoveredDevices[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: AvailableTvListItem(
                  device: device,
                  supportNote: PairingPageData.discoverySupportNoteForDevice(
                    device: device,
                    l10n: AppLocalizations.of(context)!,
                  ),
                  pairingNote: _pairingNoteForDevice(
                    device.id,
                    AppLocalizations.of(context)!,
                  ),
                  onTap: () => unawaited(_selectDevice(device)),
                ),
              );
            },
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
      ],
    );
  }

  String? _pairingNoteForDevice(String deviceId, AppLocalizations l10n) {
    return PairingPageData.pairingNoteForDevice(
      deviceId: deviceId,
      savedDeviceIds: _viewState.savedDeviceIds,
      pairingHistoryByDeviceId: _viewState.pairingHistoryByDeviceId,
      l10n: l10n,
    );
  }
}
