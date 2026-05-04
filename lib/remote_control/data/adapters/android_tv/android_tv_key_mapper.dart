import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

class AndroidTvKeyMapper extends CommandKeyMap {
  const AndroidTvKeyMapper();

  @override
  List<String> keyCodesFor(RemoteCommand command) {
    final code = _kAndroidTvCommandMap[command];
    return code == null ? const [] : [code];
  }
}

// Integer values are RemoteKeyCode enum constants from remotemessage.proto (tronikos/androidtvremote2).
const Map<RemoteCommand, String> _kAndroidTvCommandMap = {
  RemoteCommand.dpadUp:      '19',
  RemoteCommand.dpadDown:    '20',
  RemoteCommand.dpadLeft:    '21',
  RemoteCommand.dpadRight:   '22',
  RemoteCommand.dpadOk:      '23',
  RemoteCommand.back:         '4',
  RemoteCommand.home:         '3',
  RemoteCommand.volumeUp:    '24',
  RemoteCommand.volumeDown:  '25',
  RemoteCommand.mute:       '164',
  RemoteCommand.power:       '26',
  RemoteCommand.channelUp:  '166',
  RemoteCommand.channelDown:'167',
  RemoteCommand.menu:        '82',
  RemoteCommand.playPause:   '85',
  RemoteCommand.input:      '178',
  RemoteCommand.web:         '64',
  // RemoteCommand.netflix:    — no KEYCODE_NETFLIX in RemoteKeyCode enum; unsupported
  // RemoteCommand.primeVideo: — no matching constant in RemoteKeyCode enum; unsupported
  // RemoteCommand.disneyPlus: — no matching constant in RemoteKeyCode enum; unsupported
};
