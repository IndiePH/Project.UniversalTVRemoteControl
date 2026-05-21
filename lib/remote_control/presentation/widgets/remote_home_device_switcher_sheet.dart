import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Bottom sheet for switching the active TV without re-entering pairing.
class RemoteHomeDeviceSwitcherSheet extends StatelessWidget {
  const RemoteHomeDeviceSwitcherSheet({
    super.key,
    required this.devices,
    required this.activeDeviceId,
    required this.onDeviceSelected,
    required this.onManageDevices,
  });

  final List<TvDevice> devices;
  final String? activeDeviceId;
  final ValueChanged<TvDevice> onDeviceSelected;
  final VoidCallback onManageDevices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.remoteDeviceSwitcherTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isActive = device.id == activeDeviceId;
                return ListTile(
                  title: Text(device.displayName),
                  subtitle: Text(device.brand.displayName),
                  trailing: isActive
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  selected: isActive,
                  onTap: isActive ? null : () => onDeviceSelected(device),
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_remote_outlined),
            title: Text(l10n.remoteDeviceSwitcherManageButton),
            onTap: onManageDevices,
          ),
        ],
      ),
    );
  }
}
