import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

class TclRokuKeyMapper extends CommandKeyMap {
  const TclRokuKeyMapper();

  @override
  CommandPayload? payloadFor(RemoteCommand command) => _payloads[command];
}

const Map<RemoteCommand, CommandPayload> _payloads = {
  RemoteCommand.power: KeySequence(['Power']),
  RemoteCommand.playPause: KeySequence(['Play']),
  RemoteCommand.volumeUp: KeySequence(['VolumeUp']),
  RemoteCommand.volumeDown: KeySequence(['VolumeDown']),
  RemoteCommand.channelUp: KeySequence(['ChannelUp']),
  RemoteCommand.channelDown: KeySequence(['ChannelDown']),
  RemoteCommand.mute: KeySequence(['VolumeMute']),
  RemoteCommand.input: KeySequence(['InputTuner']),
  RemoteCommand.dpadUp: KeySequence(['Up']),
  RemoteCommand.dpadDown: KeySequence(['Down']),
  RemoteCommand.dpadLeft: KeySequence(['Left']),
  RemoteCommand.dpadRight: KeySequence(['Right']),
  RemoteCommand.dpadOk: KeySequence(['Select']),
  RemoteCommand.back: KeySequence(['Back']),
  RemoteCommand.home: KeySequence(['Home']),
  RemoteCommand.menu: KeySequence(['Info']),
  // Roku channel ids, dispatched via `launchApp` rather than `sendKey`.
  RemoteCommand.netflix: AppLink('12'),
  RemoteCommand.primeVideo: AppLink('13'),
  RemoteCommand.youtube: AppLink('837'),
  RemoteCommand.disneyPlus: AppLink('291097'),
};
