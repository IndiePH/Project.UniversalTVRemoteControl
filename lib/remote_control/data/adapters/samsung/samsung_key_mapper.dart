import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_app_launch.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

/// Maps app-level command enums to Samsung remote key codes and app-launch ids.
final class SamsungKeyMapper extends CommandKeyMap {
  const SamsungKeyMapper();

  @override
  CommandPayload? payloadFor(RemoteCommand command) => _payloads[command];
}

const Map<RemoteCommand, CommandPayload> _payloads = {
  RemoteCommand.power: KeySequence(['KEY_POWER']),
  RemoteCommand.playPause: KeySequence(['KEY_PLAYPAUSE']),
  RemoteCommand.volumeUp: KeySequence(['KEY_VOLUP']),
  RemoteCommand.volumeDown: KeySequence(['KEY_VOLDOWN']),
  RemoteCommand.channelUp: KeySequence(['KEY_CHUP']),
  RemoteCommand.channelDown: KeySequence(['KEY_CHDOWN']),
  RemoteCommand.mute: KeySequence(['KEY_MUTE']),
  RemoteCommand.input: KeySequence(['KEY_SOURCE']),
  // App shortcuts launch via Tizen `ed.apps.launch` (physical keys often no-op).
  // Dispatched via `launchApp`, not `sendKey` — see SamsungAdapter.sendCommand.
  RemoteCommand.web: AppLink(SamsungTizenAppIds.browser),
  RemoteCommand.netflix: AppLink(SamsungTizenAppIds.netflix),
  RemoteCommand.primeVideo: AppLink(SamsungTizenAppIds.primeVideo),
  RemoteCommand.disneyPlus: AppLink(SamsungTizenAppIds.disneyPlus),
  RemoteCommand.youtube: AppLink(SamsungTizenAppIds.youtube),
  RemoteCommand.dpadUp: KeySequence(['KEY_UP']),
  RemoteCommand.dpadDown: KeySequence(['KEY_DOWN']),
  RemoteCommand.dpadLeft: KeySequence(['KEY_LEFT']),
  RemoteCommand.dpadRight: KeySequence(['KEY_RIGHT']),
  RemoteCommand.dpadOk: KeySequence(['KEY_ENTER']),
  // Firmwares vary on back alias; sendCommand publishes each in order.
  RemoteCommand.back: KeySequence(['KEY_RETURN', 'KEY_BACK']),
  RemoteCommand.home: KeySequence(['KEY_HOME']),
  // Keep menu first, then try common settings/option aliases.
  RemoteCommand.menu: KeySequence([
    'KEY_MENU',
    'KEY_SETTINGS',
    'KEY_SETTING',
    'KEY_OPTION',
  ]),
};
