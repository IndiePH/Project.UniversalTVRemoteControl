import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_coordinator.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_data.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_dialogs.dart';
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
    this.activeDeviceId,
  });

  final RemoteCommandService commandService;
  final DeviceDiscoveryService discoveryService;
  final DeviceRepository deviceRepository;
  final PrePairingStepsRegistry stepsRegistry;
  final PairingProgressHintRegistry hintRegistry;
  final TvReachabilityService reachabilityService;
  final String? activeDeviceId;

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  PairingPageViewState _viewState = const PairingPageViewState();
  TvDevice? _activePairingDevice;
  late final PairingPageCoordinator _pairingCoordinator = PairingPageCoordinator(
    commandService: widget.commandService,
    deviceRepository: widget.deviceRepository,
  );

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scanDevices();
    _loadRecentManualIps();
    _loadPairingMetadata();
  }

  Future<void> _loadRecentManualIps() async {
    final ips = await PairingPageData.loadRecentManualIps(widget.deviceRepository);
    if (!mounted) {
      return;
    }
    setState(() {
      _viewState = _viewState.copyWith(recentManualIps: ips);
    });
  }

  Future<void> _loadPairingMetadata() async {
    final metadata = await PairingPageData.loadPairingMetadata(
      widget.deviceRepository,
    );

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
      setState(() {
        _viewState = _viewState.copyWith(discoveredDevices: discovered);
      });
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

  void _selectPairedDevice(TvDevice device) {
    Navigator.of(context).pop(device);
  }

  Future<void> _selectDevice(TvDevice device) async {
    final steps = widget.stepsRegistry.stepsFor(device.brand, device.protocolVariant);
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

  Future<void> _pairSelectedDevice({
    required TvDevice device,
    String? manualIpToSave,
  }) async {
    if (_viewState.isPairingInProgress) {
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
        promptPin: (pairingMessage) async {
          if (mounted) {
            setState(() {
              _viewState = _viewState.copyWith(isPairingInProgress: false);
            });
          }
          final pin = await PairingPageDialogs.promptPairingPin(
            context: context,
            pairingMessage: pairingMessage,
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
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
    await _loadPairingMetadata();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.pairingDeviceRemoved(device.displayName))));
  }

  Future<void> _renameDevice(TvDevice device) async {
    final newName = await PairingPageDialogs.promptRenameDevice(
      context: context,
      currentName: device.displayName,
    );
    if (newName == null || !mounted) return;
    await widget.deviceRepository.saveDevice(device.copyWith(displayName: newName));
    await _loadPairingMetadata();
  }

  Future<void> _addManualDevice({
    required TvBrand brand,
    required String ip,
  }) async {
    final device = PairingPageData.buildManualDevice(brand: brand, ip: ip);
    await _pairSelectedDevice(device: device, manualIpToSave: ip);
  }

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

  Widget _buildScrollBody() {
    final savedDevices = _viewState.savedDevices;
    return CustomScrollView(
      slivers: [
        if (savedDevices.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: const RemoteSelectionSectionHeader('Paired'),
            ),
          ),
          SliverList.builder(
            itemCount: savedDevices.length,
            itemBuilder: (context, index) {
              final device = savedDevices[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: PairedTvListItem(
                  key: ValueKey('${device.id}_${_viewState.scanCount}'),
                  device: device,
                  pairedAt: _viewState.pairingHistoryByDeviceId[device.id],
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
                  onTap: () => _selectPairedDevice(device),
                ),
              );
            },
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: const RemoteSelectionSectionHeader('Available'),
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
                child: Text(AppLocalizations.of(context)!.pairingNoDevicesFound),
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
                  pairingNote: _pairingNoteForDevice(device.id, AppLocalizations.of(context)!),
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
