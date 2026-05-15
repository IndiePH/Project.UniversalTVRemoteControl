import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

class TclLegacyKeyMapper extends CommandKeyMap {
  const TclLegacyKeyMapper();

  @override
  List<String> keyCodesFor(RemoteCommand command) {
    final code = _map[command];
    return code == null ? const [] : [code];
  }
}

const Map<RemoteCommand, String> _map = {
  RemoteCommand.power: 'KEY_POWER',
  RemoteCommand.playPause: 'KEY_PLAYPAUSE',
  RemoteCommand.volumeUp: 'KEY_VOLUMEUP',
  RemoteCommand.volumeDown: 'KEY_VOLUMEDOWN',
  RemoteCommand.channelUp: 'KEY_CHANNELUP',
  RemoteCommand.channelDown: 'KEY_CHANNELDOWN',
  RemoteCommand.mute: 'KEY_MUTE',
  RemoteCommand.input: 'KEY_SOURCE',
  RemoteCommand.dpadUp: 'KEY_UP',
  RemoteCommand.dpadDown: 'KEY_DOWN',
  RemoteCommand.dpadLeft: 'KEY_LEFT',
  RemoteCommand.dpadRight: 'KEY_RIGHT',
  RemoteCommand.dpadOk: 'KEY_OK',
  RemoteCommand.back: 'KEY_BACK',
  RemoteCommand.home: 'KEY_HOME',
  RemoteCommand.menu: 'KEY_MENU',
};
