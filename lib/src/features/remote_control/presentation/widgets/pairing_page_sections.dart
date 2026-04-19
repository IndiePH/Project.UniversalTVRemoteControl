import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/src/theme/app_theme.dart';

/// Busy overlay shown while waiting for TV-side pairing confirmation.
class PairingBusyOverlay extends StatelessWidget {
  const PairingBusyOverlay({
    super.key,
    required this.visible,
  });

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    final appColors = AppTheme.colorsOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: ModalBarrier(
            dismissible: false,
            color: appColors.pairingModalBarrier,
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: appColors.remoteRaisedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: appColors.remoteOutline, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: appColors.pairingBusyOnCard,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Waiting for TV approval...',
                  style: TextStyle(
                    color: appColors.pairingBusyOnCard,
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
}

/// Horizontally scrollable list of saved devices and quick reconnect actions.
class PairingSavedDevicesSection extends StatelessWidget {
  const PairingSavedDevicesSection({
    super.key,
    required this.devices,
    required this.pairingNoteForDevice,
    required this.onSelectDevice,
    required this.onRemoveSavedDevice,
  });

  final List<TvDevice> devices;
  final String? Function(String deviceId) pairingNoteForDevice;
  final void Function(TvDevice device) onSelectDevice;
  final void Function(TvDevice device) onRemoveSavedDevice;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
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
            itemCount: devices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final device = devices[index];
              final pairingNote = pairingNoteForDevice(device.id);
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
                    onPressed: () => onRemoveSavedDevice(device),
                    icon: const Icon(Icons.delete_outline),
                  ),
                  onTap: () => onSelectDevice(device),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Discovery result list for scanned TVs.
class PairingDiscoveryList extends StatelessWidget {
  const PairingDiscoveryList({
    super.key,
    required this.isLoading,
    required this.discoveredDevices,
    required this.pairingNoteForDevice,
    required this.onSelectDevice,
  });

  final bool isLoading;
  final List<TvDevice> discoveredDevices;
  final String? Function(String deviceId) pairingNoteForDevice;
  final void Function(TvDevice device) onSelectDevice;

  @override
  Widget build(BuildContext context) {
    if (isLoading && discoveredDevices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (discoveredDevices.isEmpty) {
      return const Center(
        child: Text('No TVs found yet. Run a scan to discover devices.'),
      );
    }
    return ListView.separated(
      itemCount: discoveredDevices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = discoveredDevices[index];
        final pairingNote = pairingNoteForDevice(device.id);
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
          onTap: () => onSelectDevice(device),
        );
      },
    );
  }
}

/// Manual brand/IP pairing form with recent IP shortcuts.
class PairingManualAddSection extends StatelessWidget {
  const PairingManualAddSection({
    super.key,
    required this.manualBrand,
    required this.manualIpController,
    required this.manualErrorMessage,
    required this.recentManualIps,
    required this.onManualBrandChanged,
    required this.onManualIpChanged,
    required this.onRecentIpSelected,
    required this.onAddManualDevice,
  });

  final TvBrand manualBrand;
  final TextEditingController manualIpController;
  final String? manualErrorMessage;
  final List<String> recentManualIps;
  final void Function(TvBrand brand) onManualBrandChanged;
  final VoidCallback onManualIpChanged;
  final void Function(String ip) onRecentIpSelected;
  final VoidCallback onAddManualDevice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Manual Pairing', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<TvBrand>(
          initialValue: manualBrand,
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
            onManualBrandChanged(brand);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: manualIpController,
          decoration: const InputDecoration(
            labelText: 'TV IP address',
            hintText: 'e.g. 192.168.1.20',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => onManualIpChanged(),
        ),
        if (recentManualIps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recentManualIps
                .map(
                  (ip) => ActionChip(
                    label: Text(ip),
                    onPressed: () => onRecentIpSelected(ip),
                  ),
                )
                .toList(),
          ),
        ],
        if (manualErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            manualErrorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        PairingActionButton(label: 'Add Manually', onPressed: onAddManualDevice),
      ],
    );
  }
}

class PairingActionButton extends StatelessWidget {
  const PairingActionButton({
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
