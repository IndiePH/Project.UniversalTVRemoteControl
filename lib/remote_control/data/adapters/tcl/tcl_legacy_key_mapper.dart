import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

class TclLegacyKeyMapper extends CommandKeyMap {
  const TclLegacyKeyMapper();

  @override
  CommandPayload? payloadFor(RemoteCommand command) => _payloads[command];
}

const Map<RemoteCommand, CommandPayload> _payloads = {
  RemoteCommand.power: KeySequence(['KEY_POWER']),
  RemoteCommand.playPause: KeySequence(['KEY_PLAYPAUSE']),
  RemoteCommand.volumeUp: KeySequence(['KEY_VOLUMEUP']),
  RemoteCommand.volumeDown: KeySequence(['KEY_VOLUMEDOWN']),
  RemoteCommand.channelUp: KeySequence(['KEY_CHANNELUP']),
  RemoteCommand.channelDown: KeySequence(['KEY_CHANNELDOWN']),
  RemoteCommand.mute: KeySequence(['KEY_MUTE']),
  RemoteCommand.input: KeySequence(['KEY_SOURCE']),
  RemoteCommand.dpadUp: KeySequence(['KEY_UP']),
  RemoteCommand.dpadDown: KeySequence(['KEY_DOWN']),
  RemoteCommand.dpadLeft: KeySequence(['KEY_LEFT']),
  RemoteCommand.dpadRight: KeySequence(['KEY_RIGHT']),
  RemoteCommand.dpadOk: KeySequence(['KEY_OK']),
  RemoteCommand.back: KeySequence(['KEY_BACK']),
  RemoteCommand.home: KeySequence(['KEY_HOME']),
  RemoteCommand.menu: KeySequence(['KEY_MENU']),
};
