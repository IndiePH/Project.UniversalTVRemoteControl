import 'package:one_remote/l10n/app_localizations.dart';

/// Internal status line kinds for [RemoteHomePage].
///
/// Display strings come from [AppLocalizations] via [RemoteHomeStatusKindL10n];
/// do not compare localized text for logic.
enum RemoteHomeStatusKind {
  connectTvToBegin,
  ready,
  transportIdle,
  noDeviceSelected,
  enterTextBeforeSending,
  pairTvFirst,
  keyboardUnavailable,
}

extension RemoteHomeStatusKindL10n on RemoteHomeStatusKind {
  String localize(AppLocalizations l10n) => switch (this) {
    RemoteHomeStatusKind.connectTvToBegin => l10n.remoteStatusConnectTvToBegin,
    RemoteHomeStatusKind.ready => l10n.remoteStatusReady,
    RemoteHomeStatusKind.transportIdle => l10n.remoteStatusTransportIdle,
    RemoteHomeStatusKind.noDeviceSelected => l10n.remoteStatusNoDeviceSelected,
    RemoteHomeStatusKind.enterTextBeforeSending =>
      l10n.remoteStatusEnterTextBeforeSending,
    RemoteHomeStatusKind.pairTvFirst => l10n.remoteStatusPairTvFirst,
    RemoteHomeStatusKind.keyboardUnavailable => l10n.remoteKeyboardUnavailable,
  };
}
