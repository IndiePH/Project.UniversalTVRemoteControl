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
    required this.canSwitchDevices,
    required this.onDeviceSelected,
    required this.onManageDevices,
    this.onSwitchBlocked,
  });

  final List<TvDevice> devices;
  final String? activeDeviceId;
  final bool canSwitchDevices;
  final ValueChanged<TvDevice> onDeviceSelected;
  final VoidCallback onManageDevices;
  final VoidCallback? onSwitchBlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasLockedDevices = devices.any((device) => device.id != activeDeviceId);
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
          if (!canSwitchDevices && hasLockedDevices)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.proDeviceSwitchLockedMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isActive = device.id == activeDeviceId;
                final switchBlocked = !isActive && !canSwitchDevices;
                return ListTile(
                  title: Text(device.displayName),
                  subtitle: Text(device.brand.displayName),
                  trailing: isActive
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : switchBlocked
                      ? Tooltip(
                          message: l10n.proDeviceSwitchLockedTooltip,
                          child: Icon(
                            Icons.lock_outline,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        )
                      : null,
                  selected: isActive,
                  onTap: isActive
                      ? null
                      : () {
                          if (canSwitchDevices) {
                            onDeviceSelected(device);
                          } else {
                            onSwitchBlocked?.call();
                          }
                        },
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
