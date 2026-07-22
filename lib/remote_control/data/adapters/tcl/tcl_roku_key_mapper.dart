import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

class TclRokuKeyMapper extends CommandKeyMap {
  const TclRokuKeyMapper();

  @override
  List<String> keyCodesFor(RemoteCommand command) {
    final code = _map[command];
    return code == null ? const [] : [code];
  }
}

const Map<RemoteCommand, String> _map = {
  RemoteCommand.power: 'Power',
  RemoteCommand.playPause: 'Play',
  RemoteCommand.volumeUp: 'VolumeUp',
  RemoteCommand.volumeDown: 'VolumeDown',
  RemoteCommand.channelUp: 'ChannelUp',
  RemoteCommand.channelDown: 'ChannelDown',
  RemoteCommand.mute: 'VolumeMute',
  RemoteCommand.input: 'InputTuner',
  RemoteCommand.dpadUp: 'Up',
  RemoteCommand.dpadDown: 'Down',
  RemoteCommand.dpadLeft: 'Left',
  RemoteCommand.dpadRight: 'Right',
  RemoteCommand.dpadOk: 'Select',
  RemoteCommand.back: 'Back',
  RemoteCommand.home: 'Home',
  RemoteCommand.menu: 'Info',
};
