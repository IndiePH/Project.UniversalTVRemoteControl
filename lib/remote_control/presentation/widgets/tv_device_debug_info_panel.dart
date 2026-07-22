import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

/// Debug-only transport device details (model, firmware, extras).
class TvDeviceDebugInfoPanel extends StatelessWidget {
  const TvDeviceDebugInfoPanel({
    super.key,
    required this.device,
    required this.infoFuture,
  });

  final TvDevice? device;
  final Future<TvDeviceInfo?> Function({required TvDevice device}) infoFuture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeDevice = device;
    if (activeDevice == null) {
      return _UnavailableBody(l10n: l10n);
    }
    return FutureBuilder<TvDeviceInfo?>(
      future: infoFuture(device: activeDevice),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final info = snapshot.data;
        if (info == null || !_hasDisplayableInfo(info)) {
          return _UnavailableBody(l10n: l10n);
        }
        final unknown = l10n.settingsTvDeviceInfoUnknown;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settingsTvDeviceInfoTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '${activeDevice.brand.name} · ${activeDevice.displayName}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsTvDeviceInfoModelLine(
                info.modelIdentifier ?? unknown,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l10n.settingsTvDeviceInfoFirmwareLine(
                info.firmwareVersion ?? unknown,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (info.debugDetails != null && info.debugDetails!.isNotEmpty)
              Text(
                info.debugDetails!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        );
      },
    );
  }

  bool _hasDisplayableInfo(TvDeviceInfo info) {
    return (info.modelIdentifier != null && info.modelIdentifier!.isNotEmpty) ||
        (info.firmwareVersion != null && info.firmwareVersion!.isNotEmpty) ||
        (info.debugDetails != null && info.debugDetails!.isNotEmpty);
  }
}

class _UnavailableBody extends StatelessWidget {
  const _UnavailableBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsTvDeviceInfoTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.settingsTvDeviceInfoUnavailable,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
