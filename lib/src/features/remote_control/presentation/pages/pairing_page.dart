import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_repository.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand_capabilities.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/src/features/remote_control/presentation/formatting/two_digit_format.dart';

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
  bool _isLoading = false;
  bool _isPairingInProgress = false;
  String? _errorMessage;
  String? _manualErrorMessage;
  TvBrand _manualBrand = TvBrand.samsung;
  List<TvDevice> _savedDevices = const [];
  List<TvDevice> _discoveredDevices = const [];
  List<String> _recentManualIps = const [];
  Set<String> _savedDeviceIds = const {};
  Map<String, DateTime> _pairingHistoryByDeviceId = const {};

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
    final ips = await widget.deviceRepository.getRecentManualIps();
    if (!mounted) {
      return;
    }
    setState(() {
      _recentManualIps = ips;
    });
  }

  Future<void> _loadPairingMetadata() async {
    // Build lookup maps once so list rendering stays simple and fast.
    final savedDevices = await widget.deviceRepository.getSavedDevices();
    final savedIds = <String>{};
    final pairingHistory = <String, DateTime>{};

    for (final device in savedDevices) {
      savedIds.add(device.id);
      final pairedAt = await widget.deviceRepository.getLastSuccessfulPairingAt(
        device.id,
      );
      if (pairedAt != null) {
        pairingHistory[device.id] = pairedAt;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _savedDevices = savedDevices;
      _savedDeviceIds = savedIds;
      _pairingHistoryByDeviceId = pairingHistory;
    });
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final discovered = await widget.discoveryService.discoverDevices();
      if (!mounted) {
        return;
      }
      setState(() {
        _discoveredDevices = discovered;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Discovery failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    if (_isPairingInProgress) {
      return;
    }
    setState(() {
      _isPairingInProgress = true;
      _errorMessage = null;
      _manualErrorMessage = null;
    });

    try {
      final pairingResult = await widget.commandService.preparePairing(
        device: device,
      );
      if (!pairingResult.isSuccess) {
        final didCompleteViaPin = await _attemptHisensePinFallback(
          device: device,
          pairingMessage: pairingResult.message,
        );
        if (!didCompleteViaPin) {
          throw StateError(pairingResult.message);
        }
      }
      if (manualIpToSave != null && manualIpToSave.isNotEmpty) {
        await widget.deviceRepository.saveRecentManualIp(manualIpToSave);
      }
      final pairedAt = DateTime.now();
      await widget.deviceRepository.saveDevice(device);
      await widget.deviceRepository.setLastUsedDevice(device.id);
      await widget.deviceRepository.setLastSuccessfulPairingAt(
        deviceId: device.id,
        timestamp: pairedAt,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(device);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Pairing failed. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to pair with TV. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPairingInProgress = false;
        });
      }
    }
  }

  /// For some VIDAA firmware builds, pairing is incomplete until the user
  /// enters a 4-digit code shown on the TV. Offer that recovery step only for
  /// Hisense when the first pairing attempt failed.
  Future<bool> _attemptHisensePinFallback({
    required TvDevice device,
    required String pairingMessage,
  }) async {
    if (device.brand != TvBrand.hisense) {
      return false;
    }

    // Pause the blocking overlay while the user types a PIN.
    if (mounted) {
      setState(() {
        _isPairingInProgress = false;
      });
    }
    while (true) {
      final pin = await _promptForHisensePairingPin(pairingMessage);
      if (mounted) {
        setState(() {
          _isPairingInProgress = true;
        });
      }
      if (pin == null) {
        return false;
      }

      final submitResult = await widget.commandService.submitPairingCode(
        device: device,
        fourDigitPin: pin,
      );
      if (!mounted) {
        return false;
      }
      if (submitResult.isSuccess) {
        return true;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(submitResult.message)));
      // Show the PIN dialog again after a failed code so users can retry.
      setState(() {
        _isPairingInProgress = false;
      });
    }
  }

  Future<String?> _promptForHisensePairingPin(String pairingMessage) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? inputError;

        String? validatePin() {
          final value = controller.text.trim();
          if (!RegExp(r'^\d{4}$').hasMatch(value)) {
            return 'Enter exactly 4 digits.';
          }
          return null;
        }

        void submit(StateSetter setDialogState) {
          final error = validatePin();
          if (error != null) {
            setDialogState(() {
              inputError = error;
            });
            return;
          }
          Navigator.of(context).pop(controller.text.trim());
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enter TV pairing code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hisense TV may require a 4-digit code shown on-screen to finish pairing.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pairingMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '4-digit TV code',
                      border: const OutlineInputBorder(),
                      counterText: '',
                      errorText: inputError,
                    ),
                    onChanged: (_) {
                      if (inputError == null) {
                        return;
                      }
                      setDialogState(() {
                        inputError = null;
                      });
                    },
                    onSubmitted: (_) => submit(setDialogState),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => submit(setDialogState),
                  child: const Text('Submit code'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRemoveSavedDevice(TvDevice device) async {
    final isActiveDevice = widget.activeDeviceId == device.id;
    final removeMessage = isActiveDevice
        ? 'This is the currently connected device. Removing it may disconnect your current control session.'
        : 'This will remove "${device.displayName}" from saved devices.';

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove saved device?'),
          content: Text(removeMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    // Active-device removal has an additional guard to reduce accidental disconnects.
    if (isActiveDevice) {
      final confirmText = await _requestActiveRemovalConfirmation();
      if (confirmText != true) {
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

  Future<bool?> _requestActiveRemovalConfirmation() {
    const expectedText = 'REMOVE';
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) {
        String? inputError;

        bool isValidInput() {
          return controller.text.trim().toUpperCase() == expectedText;
        }

        void trySubmit(StateSetter setDialogState) {
          if (isValidInput()) {
            Navigator.of(context).pop(true);
            return;
          }
          setDialogState(() {
            inputError = 'Type REMOVE exactly to confirm.';
          });
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm active device removal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'To continue, type REMOVE. This helps prevent accidental disconnects.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Type REMOVE',
                      border: const OutlineInputBorder(),
                      errorText: inputError,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (inputError == null) {
                        return;
                      }
                      setDialogState(() {
                        inputError = null;
                      });
                    },
                    onSubmitted: (_) => trySubmit(setDialogState),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => trySubmit(setDialogState),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addManualDevice() async {
    final ip = _manualIpController.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _manualErrorMessage = 'Enter a TV IP address.';
      });
      return;
    }
    if (!_isValidIpv4(ip)) {
      setState(() {
        _manualErrorMessage = 'Enter a valid IPv4 address (e.g. 192.168.1.20).';
      });
      return;
    }

    final device = TvDevice(
      id: '${_manualBrand.name}-$ip',
      displayName: '${_manualBrand.name.toUpperCase()} TV ($ip)',
      brand: _manualBrand,
      capabilities: _manualBrand.defaultCapabilities,
    );
    await _pairSelectedDevice(device: device, manualIpToSave: ip);
  }

  bool _isValidIpv4(String input) {
    final regExp = RegExp(
      r'^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
    );
    return regExp.hasMatch(input);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isPairingInProgress,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pair TV'),
          automaticallyImplyLeading: !_isPairingInProgress,
        ),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isPairingInProgress,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSavedDevicesSection(),
                    const SizedBox(height: 12),
                    RemoteActionButton(
                      label: _isLoading ? 'Scanning...' : 'Scan for TVs',
                      onPressed: _isLoading ? null : _scanDevices,
                    ),
                    const SizedBox(height: 12),
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
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
            _buildPairingBusyOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingBusyOverlay() {
    if (!_isPairingInProgress) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        const Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Colors.black54),
        ),
        Center(
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
                  'Waiting for TV approval...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedDevicesSection() {
    if (_savedDevices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Saved Devices', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _savedDevices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final device = _savedDevices[index];
              final pairingNote = _pairingNoteForDevice(device.id);
              return SizedBox(
                width: 220,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Theme.of(context).colorScheme.surface,
                  title: Text(
                    device.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    pairingNote ?? device.brand.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove saved device',
                    onPressed: () => _confirmRemoveSavedDevice(device),
                    icon: const Icon(Icons.delete_outline),
                  ),
                  onTap: () => _selectDevice(device),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryList() {
    if (_isLoading && _discoveredDevices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_discoveredDevices.isEmpty) {
      return const Center(
        child: Text('No TVs found yet. Run a scan to discover devices.'),
      );
    }

    return ListView.separated(
      itemCount: _discoveredDevices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = _discoveredDevices[index];
        final pairingNote = _pairingNoteForDevice(device.id);
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: Theme.of(context).colorScheme.surface,
          title: Text(device.displayName),
          subtitle: pairingNote == null
              ? Text(device.brand.name.toUpperCase())
              : Text('${device.brand.name.toUpperCase()} • $pairingNote'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _selectDevice(device),
        );
      },
    );
  }

  String? _pairingNoteForDevice(String deviceId) {
    if (!_savedDeviceIds.contains(deviceId)) {
      return null;
    }
    final pairedAt = _pairingHistoryByDeviceId[deviceId];
    if (pairedAt == null) {
      return 'Previously paired';
    }
    final local = pairedAt.toLocal();
    final date =
        '${local.year}-${formatTwoDigits(local.month)}-${formatTwoDigits(local.day)}';
    final time = '${formatTwoDigits(local.hour)}:${formatTwoDigits(local.minute)}';
    return 'Previously paired ($date $time)';
  }

  Widget _buildManualAddSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Manual Pairing', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<TvBrand>(
          initialValue: _manualBrand,
          decoration: const InputDecoration(
            labelText: 'TV brand',
            border: OutlineInputBorder(),
          ),
          items: TvBrand.values
              .map(
                (brand) => DropdownMenuItem<TvBrand>(
                  value: brand,
                  child: Text(brand.name.toUpperCase()),
                ),
              )
              .toList(),
          onChanged: (brand) {
            if (brand == null) {
              return;
            }
            setState(() {
              _manualBrand = brand;
            });
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _manualIpController,
          decoration: const InputDecoration(
            labelText: 'TV IP address',
            hintText: 'e.g. 192.168.1.20',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) {
            if (_manualErrorMessage == null) {
              return;
            }
            setState(() {
              _manualErrorMessage = null;
            });
          },
        ),
        if (_recentManualIps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentManualIps
                .map(
                  (ip) => ActionChip(
                    label: Text(ip),
                    onPressed: () {
                      setState(() {
                        _manualIpController.text = ip;
                        _manualErrorMessage = null;
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ],
        if (_manualErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _manualErrorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        RemoteActionButton(label: 'Add Manually', onPressed: _addManualDevice),
      ],
    );
  }
}

class RemoteActionButton extends StatelessWidget {
  const RemoteActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
