import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

/// Maps [RemoteCommand] values to VIDAA MQTT `sendkey` key names, and app-shortcut
/// commands to `launchapp` targets.
///
/// See: community MQTT docs for Hisense VIDAA (`KEY_*` strings).
final class HisenseKeyMapper extends CommandKeyMap {
  const HisenseKeyMapper();

  @override
  CommandPayload? payloadFor(RemoteCommand command) => _payloads[command];
}

const Map<RemoteCommand, CommandPayload> _payloads = {
  RemoteCommand.power: KeySequence(['KEY_POWER']),
  // Many builds expose either a combined code or separate play/pause.
  RemoteCommand.playPause: KeySequence(['KEY_PLAYPAUSE', 'KEY_PLAY']),
  RemoteCommand.volumeUp: KeySequence(['KEY_VOLUMEUP']),
  RemoteCommand.volumeDown: KeySequence(['KEY_VOLUMEDOWN']),
  RemoteCommand.channelUp: KeySequence(['KEY_CHANNELUP', 'KEY_CHSUP']),
  RemoteCommand.channelDown: KeySequence(['KEY_CHANNELDOWN', 'KEY_CHSDOWN']),
  RemoteCommand.mute: KeySequence(['KEY_MUTE']),
  RemoteCommand.input: KeySequence(['KEY_SOURCE', 'KEY_INPUT']),
  RemoteCommand.dpadUp: KeySequence(['KEY_UP']),
  RemoteCommand.dpadDown: KeySequence(['KEY_DOWN']),
  RemoteCommand.dpadLeft: KeySequence(['KEY_LEFT']),
  RemoteCommand.dpadRight: KeySequence(['KEY_RIGHT']),
  RemoteCommand.dpadOk: KeySequence(['KEY_OK']),
  // README uses KEY_RETURNS for back on some firmwares.
  RemoteCommand.back: KeySequence(['KEY_RETURNS', 'KEY_RETURN', 'KEY_BACK']),
  RemoteCommand.home: KeySequence(['KEY_HOME']),
  // VIDAA firmwares vary: menu may be exposed via settings/option aliases.
  RemoteCommand.menu: KeySequence([
    'KEY_MENU',
    'KEY_SETTINGS',
    'KEY_SETTING',
    'KEY_OPTION',
  ]),
  // Dispatched via `launchVidaaApp` (MQTT `launchapp`), not `sendkey`.
  RemoteCommand.netflix: VidaaLaunch('Netflix', 'netflix'),
  RemoteCommand.primeVideo: VidaaLaunch('Amazon', 'amazon'),
  RemoteCommand.disneyPlus: VidaaLaunch('Disney+', 'disneyplus'),
  RemoteCommand.youtube: VidaaLaunch('YouTube', 'youtube'),
  // NOTE: `.web` intentionally mirrors `.youtube` here, carried over unchanged
  // from the pre-migration `_vidaaLaunchSpec` switch — see
  // `references/goals/goal-app-launch-dispatch-unification.md` Phase 4, which
  // flags this as a possible pre-existing bug and defers fixing it to a
  // separate decision.
  RemoteCommand.web: VidaaLaunch('YouTube', 'youtube'),
};
