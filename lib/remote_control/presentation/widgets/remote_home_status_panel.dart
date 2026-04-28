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
    this.highlightPairButton = false,
    this.pairButtonBlinkOn = false,
    this.overlayOnChild = false,
    required this.child,
  });

  final String deviceName;
  final String status;
  final remote_connection.ConnectionState connectionState;
  final VoidCallback onOpenPairing;
  final bool hasActiveDevice;
  final bool hasAnyPairedDevice;
  final bool highlightPairButton;
  final bool pairButtonBlinkOn;
  final bool overlayOnChild;
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

    Widget blurWhenPairFocus(Widget child) {
      if (!highlightPairButton) {
        return child;
      }
      return AnimatedOpacity(
        opacity: 0.34,
        duration: const Duration(milliseconds: 250),
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: blurWhenPairFocus(
                Text(
                  deviceName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            _PairButton(
              isActive: hasActiveDevice,
              onPressed: onOpenPairing,
              highlighted: highlightPairButton,
              blinkOn: pairButtonBlinkOn,
            ),
          ],
        ),
        blurWhenPairFocus(
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: connectionColor),
              const SizedBox(width: 8),
              Text(statusLabel),
            ],
          ),
        ),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 8),
          blurWhenPairFocus(Text(status)),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (overlayOnChild) ...[
                IgnorePointer(
                  child: Container(
                    color: appColors.pairingModalBarrier.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PairButton extends StatelessWidget {
  const _PairButton({
    required this.isActive,
    required this.onPressed,
    required this.highlighted,
    required this.blinkOn,
  });

  final bool isActive;
  final VoidCallback onPressed;
  final bool highlighted;
  final bool blinkOn;

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
      child: AnimatedScale(
        scale: highlighted && blinkOn ? 1.08 : 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: highlighted && blinkOn
                ? [
                    BoxShadow(
                      color: appColors.pairingHintGridTint.withValues(
                        alpha: 0.62,
                      ),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: Material(
            color: background,
            shape: CircleBorder(
              side: BorderSide(
                color: highlighted && blinkOn
                    ? appColors.pairingHintGridTint
                    : appColors.remoteOutline,
                width: highlighted ? 2 : 1.2,
              ),
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
