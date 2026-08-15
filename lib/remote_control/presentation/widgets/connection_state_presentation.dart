import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart'
    as remote_connection;
import 'package:one_remote/theme/app_theme.dart';

typedef ConnectionStatePresentation = ({String label, Color color});

ConnectionStatePresentation connectionStatePresentation({
  required BuildContext context,
  required remote_connection.ConnectionState state,
}) {
  final l10n = AppLocalizations.of(context)!;
  final appColors = AppTheme.colorsOf(context);
  final colorScheme = Theme.of(context).colorScheme;
  return switch (state) {
    remote_connection.ConnectionState.connected => (
      label: l10n.connectionStateConnected,
      color: appColors.remoteActionSuccessFill,
    ),
    remote_connection.ConnectionState.connecting => (
      label: l10n.connectionStateConnecting,
      color: colorScheme.secondary,
    ),
    remote_connection.ConnectionState.error => (
      label: l10n.connectionStateError,
      color: colorScheme.error,
    ),
    remote_connection.ConnectionState.unauthorized => (
      label: l10n.connectionStateUnauthorized,
      color: colorScheme.error,
    ),
    remote_connection.ConnectionState.disconnected => (
      label: l10n.connectionStateDisconnected,
      color: colorScheme.error,
    ),
  };
}

IconData connectionStateIcon(remote_connection.ConnectionState state) {
  return switch (state) {
    remote_connection.ConnectionState.connected => Icons.wifi,
    remote_connection.ConnectionState.connecting => Icons.wifi_find,
    remote_connection.ConnectionState.error => Icons.wifi_off,
    remote_connection.ConnectionState.unauthorized => Icons.phonelink_lock,
    remote_connection.ConnectionState.disconnected => Icons.wifi_off,
  };
}
