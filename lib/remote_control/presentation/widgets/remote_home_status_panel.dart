import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart'
    as remote_connection;
import 'package:one_remote/theme/app_theme.dart';

/// Header/status section shown above the remote layout canvas.
class RemoteHomeStatusPanel extends StatelessWidget {
  const RemoteHomeStatusPanel({
    super.key,
    required this.deviceName,
    required this.status,
    required this.connectionState,
    required this.onOpenPairing,
    required this.hasActiveDevice,
    required this.hasAnyPairedDevice,
    required this.child,
  });

  final String deviceName;
  final String status;
  final remote_connection.ConnectionState connectionState;
  final VoidCallback onOpenPairing;
  final bool hasActiveDevice;
  final bool hasAnyPairedDevice;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = AppTheme.colorsOf(context);
    final (connectionLabel, connectionColor) = switch (connectionState) {
      remote_connection.ConnectionState.connected => (
        l10n.connectionStateConnected,
        appColors.remoteActionSuccessFill,
      ),
      remote_connection.ConnectionState.connecting => (
        l10n.connectionStateConnecting,
        Theme.of(context).colorScheme.secondary,
      ),
      remote_connection.ConnectionState.error => (
        l10n.connectionStateError,
        Theme.of(context).colorScheme.error,
      ),
      remote_connection.ConnectionState.disconnected => (
        l10n.connectionStateDisconnected,
        Theme.of(context).colorScheme.error,
      ),
    };
    final statusLabel = hasAnyPairedDevice
        ? connectionLabel
        : l10n.connectionStateDisconnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                deviceName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _PairButton(isActive: hasActiveDevice, onPressed: onOpenPairing),
          ],
        ),
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: connectionColor),
            const SizedBox(width: 8),
            Text(statusLabel),
          ],
        ),
        if (status.isNotEmpty) ...[const SizedBox(height: 8), Text(status)],
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    );
  }
}

class _PairButton extends StatelessWidget {
  const _PairButton({required this.isActive, required this.onPressed});

  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final appColors = AppTheme.colorsOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final background = isActive
        ? appColors.remoteActionSuccessFill
        : appColors.remoteSurface;
    final foreground = isActive
        ? appColors.remoteActionSuccessOnFill
        : colorScheme.onSurface;

    return Tooltip(
      message: AppLocalizations.of(context)!.connectTvTooltip,
      child: Material(
        color: background,
        shape: CircleBorder(
          side: BorderSide(color: appColors.remoteOutline, width: 1.2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: _RemoteConnectionGlyph(color: foreground)),
          ),
        ),
      ),
    );
  }
}

class _RemoteConnectionGlyph extends StatelessWidget {
  const _RemoteConnectionGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.settings_remote, size: 24, color: color),
        Positioned(
          right: -2,
          top: -2,
          child: const SizedBox.shrink(),
          // child: Icon(Icons.wifi, size: 13, color: color),
        ),
      ],
    );
  }
}
