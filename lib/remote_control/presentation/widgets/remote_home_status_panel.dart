import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart'
    as remote_connection;
import 'package:one_remote/remote_control/presentation/widgets/connection_state_presentation.dart';
import 'package:one_remote/remote_control/presentation/widgets/tv_connection_state_indicator.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_button_metrics.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_header_metrics.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_home_status_panel_metrics.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_pairing_hint_metrics.dart';
import 'package:one_remote/theme/app_theme.dart';

/// Header/status section shown above the remote layout canvas.
class RemoteHomeStatusPanel extends StatelessWidget {
  const RemoteHomeStatusPanel({
    super.key,
    required this.deviceName,
    required this.status,
    required this.connectionState,
    required this.onOpenPairing,
    this.onOpenDeviceSwitcher,
    required this.hasActiveDevice,
    required this.hasAnyPairedDevice,
    this.highlightPairButton = false,
    this.pairButtonBlinkOn = false,
    this.overlayOnChild = false,
    this.retryCountdownSeconds,
    this.onRetryNow,
    required this.child,
  });

  final String deviceName;
  final String status;
  final remote_connection.ConnectionState connectionState;
  final VoidCallback onOpenPairing;
  final VoidCallback? onOpenDeviceSwitcher;
  final bool hasActiveDevice;
  final bool hasAnyPairedDevice;
  final bool highlightPairButton;
  final bool pairButtonBlinkOn;
  final bool overlayOnChild;

  /// Seconds remaining in the automatic-reconnect wait phase, or `null` when
  /// not currently waiting. When non-null, replaces the plain status line
  /// with a countdown and a retry-now action (see
  /// `references/goals/goal-automatic-reconnection-resilience.md` SG1/T1.1).
  final int? retryCountdownSeconds;

  /// Invoked when the retry-now icon is tapped. Only meaningful (and only
  /// rendered) alongside a non-null [retryCountdownSeconds].
  final VoidCallback? onRetryNow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = AppTheme.colorsOf(context);
    final presentation = connectionStatePresentation(
      context: context,
      state: connectionState,
    );
    final connectionLabel = presentation.label;
    final statusLabel = hasAnyPairedDevice
        ? connectionLabel
        : l10n.connectionStateDisconnected;

    Widget blurWhenPairFocus(Widget child) {
      if (!highlightPairButton) {
        return child;
      }
      return AnimatedOpacity(
        opacity: RemoteHomeStatusPanelMetrics.pairingHintBlurOpacity,
        duration: kRemotePairingHintFadeDuration,
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: kRemoteLayoutHeaderHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: blurWhenPairFocus(
                      _DeviceNameHeader(
                        deviceName: deviceName,
                        onOpenDeviceSwitcher: onOpenDeviceSwitcher,
                      ),
                    ),
                  ),
                  _PairButton(
                    isActive: hasActiveDevice,
                    hasAnyPairedDevice: hasAnyPairedDevice,
                    onPressed: onOpenPairing,
                    highlighted: highlightPairButton,
                    blinkOn: pairButtonBlinkOn,
                  ),
                ],
              ),
              blurWhenPairFocus(
                Row(
                  children: [
                    TvConnectionStateIndicator(
                      state: connectionState,
                      style: TvConnectionStateIndicatorStyle.statusDot,
                      dotSize: RemoteHomeStatusPanelMetrics.connectionDotSize,
                    ),
                    const SizedBox(
                      width: RemoteHomeStatusPanelMetrics.connectionRowSpacing,
                    ),
                    Text(statusLabel),
                  ],
                ),
              ),
              if (retryCountdownSeconds != null) ...[
                const SizedBox(
                  height: RemoteHomeStatusPanelMetrics.statusLineSpacing,
                ),
                blurWhenPairFocus(
                  _RetryCountdownRow(
                    secondsRemaining: retryCountdownSeconds!,
                    onRetryNow: onRetryNow,
                  ),
                ),
              ] else if (status.isNotEmpty) ...[
                const SizedBox(
                  height: RemoteHomeStatusPanelMetrics.statusLineSpacing,
                ),
                blurWhenPairFocus(Text(status)),
              ],
            ],
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (overlayOnChild) ...[
                IgnorePointer(
                  child: Container(
                    color: appColors.pairingModalBarrier.withValues(
                      alpha: 0.45,
                    ),
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

class _DeviceNameHeader extends StatelessWidget {
  const _DeviceNameHeader({
    required this.deviceName,
    required this.onOpenDeviceSwitcher,
  });

  final String deviceName;
  final VoidCallback? onOpenDeviceSwitcher;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      deviceName,
      style: Theme.of(context).textTheme.titleLarge,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (onOpenDeviceSwitcher == null) {
      return title;
    }
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.remoteSwitchDeviceTooltip,
      child: InkWell(
        onTap: onOpenDeviceSwitcher,
        borderRadius: BorderRadius.circular(
          RemoteHomeStatusPanelMetrics.deviceSwitcherInkWellRadius,
        ),
        child: Row(
          children: [
            Flexible(fit: FlexFit.loose, child: title),
            const SizedBox(
              width: RemoteHomeStatusPanelMetrics.deviceSwitcherDropdownSpacing,
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

class _PairButton extends StatelessWidget {
  const _PairButton({
    required this.isActive,
    required this.hasAnyPairedDevice,
    required this.onPressed,
    required this.highlighted,
    required this.blinkOn,
  });

  final bool isActive;
  final bool hasAnyPairedDevice;
  final VoidCallback onPressed;
  final bool highlighted;
  final bool blinkOn;

  @override
  Widget build(BuildContext context) {
    final appColors = AppTheme.colorsOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final usePairingHintTone =
        !isActive && (!hasAnyPairedDevice || (highlighted && blinkOn));
    final background = isActive
        ? appColors.remoteActionSuccessFill
        : appColors.remoteSurface;
    final foreground = isActive
        ? appColors.remoteActionSuccessOnFill
        : colorScheme.onSurface;

    return Tooltip(
      message: AppLocalizations.of(context)!.connectTvTooltip,
      child: AnimatedScale(
        scale: highlighted && blinkOn
            ? RemoteHomeStatusPanelMetrics.pairButtonHighlightedScale
            : 1,
        duration: RemoteHomeStatusPanelMetrics.pairButtonAnimationDuration,
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: RemoteHomeStatusPanelMetrics.pairButtonAnimationDuration,
          curve: Curves.easeInOut,
          // No padding here: BoxShadow extends outside the box without
          // affecting layout, so the glow ring renders without inflating the
          // bounding box past [kRemoteHeaderButtonSize]. Keeping the box at
          // the same size as [RemoteHeaderIconButton] is what makes the home
          // and editor headers line up.
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
                color: usePairingHintTone
                    ? appColors.pairingHintGridTint
                    : appColors.remoteOutline,
                width: highlighted ? 2 : kRemoteHeaderButtonBorderWidth,
              ),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: kRemoteHeaderButtonSize,
                height: kRemoteHeaderButtonSize,
                child: Center(child: _RemoteConnectionGlyph(color: foreground)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryCountdownRow extends StatelessWidget {
  const _RetryCountdownRow({
    required this.secondsRemaining,
    required this.onRetryNow,
  });

  final int secondsRemaining;
  final VoidCallback? onRetryNow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(l10n.remoteStatusRetryingIn(secondsRemaining))),
        if (onRetryNow != null)
          Tooltip(
            message: l10n.remoteRetryNowTooltip,
            child: InkWell(
              onTap: onRetryNow,
              borderRadius: BorderRadius.circular(
                RemoteHomeStatusPanelMetrics.deviceSwitcherInkWellRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.refresh,
                  size: RemoteHomeStatusPanelMetrics.connectionDotSize * 2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RemoteConnectionGlyph extends StatelessWidget {
  const _RemoteConnectionGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.settings_remote,
      size: kRemoteHeaderButtonIconSize,
      color: color,
    );
  }
}
