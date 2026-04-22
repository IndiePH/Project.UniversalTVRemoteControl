import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_repository.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/pairing_page_coordinator.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/pairing_page_data.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/pairing_page_dialogs.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/pairing_page_view_state.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/pairing_page_sections.dart';

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
    this.activeDeviceId,
  });

  final RemoteCommandService commandService;
  final DeviceDiscoveryService discoveryService;
  final DeviceRepository deviceRepository;
  final String? activeDeviceId;

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final TextEditingController _manualIpController = TextEditingController();
  PairingPageViewState _viewState = const PairingPageViewState();
  late final PairingPageCoordinator _pairingCoordinator = PairingPageCoordinator(
    commandService: widget.commandService,
    deviceRepository: widget.deviceRepository,
  );

  @override
  void dispose() {
    _manualIpController.dispose();
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
          errorMessage: 'Discovery failed. Please try again.',
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

  Future<void> _selectDevice(TvDevice device) async {
    await _pairSelectedDevice(device: device);
  }

  Future<void> _pairSelectedDevice({
    required TvDevice device,
    String? manualIpToSave,
  }) async {
    if (_viewState.isPairingInProgress) {
      return;
    }
    final pairingHint = device.brand == TvBrand.lg
        ? 'Look at your TV screen and accept the pairing prompt.'
        : null;

    setState(() {
      _viewState = _viewState.copyWith(
        isPairingInProgress: true,
        pairingHint: pairingHint,
        clearErrorMessage: true,
        clearManualErrorMessage: true,
      );
    });

    try {
      final result = await _pairingCoordinator.pairSelectedDevice(
        device: device,
        manualIpToSave: manualIpToSave,
        promptHisensePin: (pairingMessage) async {
          if (mounted) {
            setState(() {
              _viewState = _viewState.copyWith(isPairingInProgress: false);
            });
          }
          final pin = await PairingPageDialogs.promptHisensePairingPin(
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
        onHisensePinRejected: (message) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          setState(() {
            _viewState = _viewState.copyWith(isPairingInProgress: false);
          });
        },
      );
      if (!result.isSuccess) {
        if (!mounted) return;
        final errorMsg = result.message ?? 'Pairing failed. Please try again.';
        setState(() {
          _viewState = _viewState.copyWith(errorMessage: errorMsg);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
        return;
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(device);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _viewState = _viewState.copyWith(
          errorMessage: 'Pairing failed. Please try again.',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to pair with TV. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _viewState = _viewState.copyWith(
            isPairingInProgress: false,
            clearPairingHint: true,
          );
        });
      }
    }
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

    // Active-device removal has an additional guard to reduce accidental disconnects.
    if (isActiveDevice) {
      final confirmText = await PairingPageDialogs.confirmActiveRemoval(
        context: context,
      );
      if (!confirmText) {
        return;
      }
    }

    await widget.deviceRepository.removeSavedDevice(device.id);
    await _loadPairingMetadata();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Removed ${device.displayName}')));
  }

  Future<void> _addManualDevice() async {
    final ip = _manualIpController.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _viewState = _viewState.copyWith(
          manualErrorMessage: 'Enter a TV IP address.',
        );
      });
      return;
    }
    if (!PairingPageData.isValidIpv4(ip)) {
      setState(() {
        _viewState = _viewState.copyWith(
          manualErrorMessage: 'Enter a valid IPv4 address (e.g. 192.168.1.20).',
        );
      });
      return;
    }

    final device = PairingPageData.buildManualDevice(
      brand: _viewState.manualBrand,
      ip: ip,
    );
    await _pairSelectedDevice(device: device, manualIpToSave: ip);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_viewState.isPairingInProgress,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pair TV'),
          automaticallyImplyLeading: !_viewState.isPairingInProgress,
          actions: [
            IconButton(
              tooltip: 'Pairing help',
              icon: const Icon(Icons.help_outline),
              onPressed: _viewState.isPairingInProgress
                  ? null
                  : _showPairingHelp,
            ),
          ],
        ),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _viewState.isPairingInProgress,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSavedDevicesSection(),
                    const SizedBox(height: 12),
                    PairingActionButton(
                      label: _viewState.isLoading ? 'Scanning...' : 'Scan for TVs',
                      onPressed: _viewState.isLoading ? null : _scanDevices,
                    ),
                    const SizedBox(height: 12),
                    if (_viewState.errorMessage != null) ...[
                      Text(
                        _viewState.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Expanded(child: _buildDiscoveryList()),
                    const SizedBox(height: 12),
                    _buildManualAddSection(),
                  ],
                ),
              ),
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

  Widget _buildSavedDevicesSection() {
    return PairingSavedDevicesSection(
      devices: _viewState.savedDevices,
      pairingNoteForDevice: _pairingNoteForDevice,
      onSelectDevice: (device) => unawaited(_selectDevice(device)),
      onRemoveSavedDevice: (device) => unawaited(_confirmRemoveSavedDevice(device)),
    );
  }

  Widget _buildDiscoveryList() {
    return PairingDiscoveryList(
      isLoading: _viewState.isLoading,
      discoveredDevices: _viewState.discoveredDevices,
      pairingNoteForDevice: _pairingNoteForDevice,
      onSelectDevice: (device) => unawaited(_selectDevice(device)),
    );
  }

  String? _pairingNoteForDevice(String deviceId) {
    return PairingPageData.pairingNoteForDevice(
      deviceId: deviceId,
      savedDeviceIds: _viewState.savedDeviceIds,
      pairingHistoryByDeviceId: _viewState.pairingHistoryByDeviceId,
    );
  }

  Widget _buildManualAddSection() {
    return PairingManualAddSection(
      manualBrand: _viewState.manualBrand,
      manualIpController: _manualIpController,
      manualErrorMessage: _viewState.manualErrorMessage,
      recentManualIps: _viewState.recentManualIps,
      onManualBrandChanged: (brand) {
        setState(() {
          _viewState = _viewState.copyWith(manualBrand: brand);
        });
      },
      onManualIpChanged: () {
        if (_viewState.manualErrorMessage == null) {
          return;
        }
        setState(() {
          _viewState = _viewState.copyWith(clearManualErrorMessage: true);
        });
      },
      onRecentIpSelected: (ip) {
        setState(() {
          _manualIpController.text = ip;
          _viewState = _viewState.copyWith(clearManualErrorMessage: true);
        });
      },
      onAddManualDevice: () => unawaited(_addManualDevice()),
    );
  }
}
