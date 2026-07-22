import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

class AndroidTvKeyMapper extends CommandKeyMap {
  const AndroidTvKeyMapper();

  @override
  List<String> keyCodesFor(RemoteCommand command) {
    final codes = _kAndroidTvCommandMap[command];
    return codes == null ? const [] : List<String>.unmodifiable(codes);
  }
}

// Integer values are RemoteKeyCode enum constants from remotemessage.proto (tronikos/androidtvremote2).
const Map<RemoteCommand, List<String>> _kAndroidTvCommandMap = {
  RemoteCommand.dpadUp: ['19'],
  RemoteCommand.dpadDown: ['20'],
  RemoteCommand.dpadLeft: ['21'],
  RemoteCommand.dpadRight: ['22'],
  RemoteCommand.dpadOk: ['23'],
  RemoteCommand.back: ['4'],
  RemoteCommand.home: ['3'],
  RemoteCommand.volumeUp: ['24'],
  RemoteCommand.volumeDown: ['25'],
  RemoteCommand.mute: ['164'],
  RemoteCommand.power: ['26'],
  RemoteCommand.channelUp: ['166'],
  RemoteCommand.channelDown: ['167'],
  // Some builds map menu behavior to either MENU (82) or SETTINGS (176).
  RemoteCommand.menu: ['82', '176'],
  RemoteCommand.playPause: ['85'],
  RemoteCommand.input: ['178'],
  RemoteCommand.web: ['64'],
};
