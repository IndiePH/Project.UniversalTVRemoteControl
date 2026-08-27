import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

/// Maps [RemoteCommand] values to Sony BRAVIA IRCC-IP remote-key command
/// *names* (e.g. `'Up'`, `'VolumeUp'`) — resolved by
/// `SonyBraviaHttpTransportClient` against each device's own
/// `getRemoteControllerInfo` response, never a hardcoded base64 table (Sony
/// assigns the actual codes per model/firmware). Names below are Sony's own
/// conventional IRCC command names, cross-checked against two independently
/// sourced real-device code dumps (see `guide-tv-remote-protocols.md`'s
/// "Sony BRAVIA IP Control" section for citations) — where the two sources
/// disagreed on the name for an identical code (e.g. `Power` vs `TvPower`),
/// both are listed as ordered aliases, same convention Hisense's key mapper
/// already uses for cross-firmware naming drift.
///
/// Intentionally unmapped (`payloadFor` returns `null`, so these fall out of
/// `supportedCommands` the same way any other brand's unsupported command
/// does):
/// - `playPause` — no single toggle code exists in either source; `Play` and
///   `Pause` are genuinely different actions, not aliases of one action, so
///   aliasing them via `KeySequence` would send the wrong one half the time.
/// - `netflix`/`primeVideo`/`disneyPlus`/`youtube`/`web` — app launch is a
///   separate, per-device-dynamic mechanism (`getApplicationList`) not yet
///   wired up; see the guide's scope note.
final class SonyBraviaKeyMapper extends CommandKeyMap {
  const SonyBraviaKeyMapper();

  @override
  CommandPayload? payloadFor(RemoteCommand command) => _payloads[command];
}

const Map<RemoteCommand, CommandPayload> _payloads = {
  RemoteCommand.power: KeySequence(['Power', 'TvPower']),
  RemoteCommand.volumeUp: KeySequence(['VolumeUp']),
  RemoteCommand.volumeDown: KeySequence(['VolumeDown']),
  RemoteCommand.channelUp: KeySequence(['ChannelUp']),
  RemoteCommand.channelDown: KeySequence(['ChannelDown']),
  RemoteCommand.mute: KeySequence(['Mute']),
  RemoteCommand.input: KeySequence(['Input', 'TvInput']),
  RemoteCommand.dpadUp: KeySequence(['Up']),
  RemoteCommand.dpadDown: KeySequence(['Down']),
  RemoteCommand.dpadLeft: KeySequence(['Left']),
  RemoteCommand.dpadRight: KeySequence(['Right']),
  RemoteCommand.dpadOk: KeySequence(['Confirm']),
  RemoteCommand.back: KeySequence(['Return']),
  RemoteCommand.home: KeySequence(['Home']),
  // Uncertain vs. 'TopMenu'/'AndroidMenu' — 'Options' was picked because it's
  // the one name both source dumps agree on; revisit during on-device
  // validation (mirrors how TCL's market:// override is flagged pending
  // hardware confirmation elsewhere in this codebase).
  RemoteCommand.menu: KeySequence(['Options']),
};
