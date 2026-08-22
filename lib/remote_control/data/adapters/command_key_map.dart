import 'package:one_remote/remote_control/domain/models/remote_command.dart';

/// The payload for one [RemoteCommand], and which transport method dispatches it.
///
/// One subclass per transport method, not per data shape — [KeySequence] covers both
/// a single key code and several ordered fallback aliases, since both are dispatched
/// via `sendKey` identically.
sealed class CommandPayload {
  const CommandPayload();
}

/// Dispatched via `sendKey`/`sendFrame`. One or more ordered fallback aliases to try.
final class KeySequence extends CommandPayload {
  const KeySequence(this.codes);
  final List<String> codes;

  @override
  bool operator ==(Object other) =>
      other is KeySequence && _listEquals(other.codes, codes);

  @override
  int get hashCode => Object.hashAll(codes);
}

/// Dispatched via an app-link/launch-app transport method. Carries the raw app id or
/// deep-link URI with no sentinel prefix — the type itself signals "this is an app link."
final class AppLink extends CommandPayload {
  const AppLink(this.uri);
  final String uri;

  @override
  bool operator ==(Object other) => other is AppLink && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

/// Dispatched via Hisense's `launchVidaaApp`.
final class VidaaLaunch extends CommandPayload {
  const VidaaLaunch(this.displayName, this.url);
  final String displayName;
  final String url;

  @override
  bool operator ==(Object other) =>
      other is VidaaLaunch &&
      other.displayName == displayName &&
      other.url == url;

  @override
  int get hashCode => Object.hash(displayName, url);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Shared abstraction that maps app commands to brand-specific dispatch payloads.
abstract class CommandKeyMap {
  const CommandKeyMap();

  /// Returns the payload for [command], or `null` if this brand/variant doesn't support it.
  CommandPayload? payloadFor(RemoteCommand command);
}
