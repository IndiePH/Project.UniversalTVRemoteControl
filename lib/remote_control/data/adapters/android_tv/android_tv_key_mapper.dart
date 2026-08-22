import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

class AndroidTvKeyMapper extends CommandKeyMap {
  const AndroidTvKeyMapper();

  @override
  CommandPayload? payloadFor(RemoteCommand command) => _payloads[command];
}

// Integer key-code values are RemoteKeyCode enum constants from remotemessage.proto
// (tronikos/androidtvremote2). App-launch entries are shared by AndroidTv and
// TclGoogleTv, both of which dispatch via `sendAppLink`.
const Map<RemoteCommand, CommandPayload> _payloads = {
  RemoteCommand.dpadUp: KeySequence(['19']),
  RemoteCommand.dpadDown: KeySequence(['20']),
  RemoteCommand.dpadLeft: KeySequence(['21']),
  RemoteCommand.dpadRight: KeySequence(['22']),
  RemoteCommand.dpadOk: KeySequence(['23']),
  RemoteCommand.back: KeySequence(['4']),
  RemoteCommand.home: KeySequence(['3']),
  RemoteCommand.volumeUp: KeySequence(['24']),
  RemoteCommand.volumeDown: KeySequence(['25']),
  RemoteCommand.mute: KeySequence(['164']),
  RemoteCommand.power: KeySequence(['26']),
  RemoteCommand.channelUp: KeySequence(['166']),
  RemoteCommand.channelDown: KeySequence(['167']),
  // Some builds map menu behavior to either MENU (82) or SETTINGS (176).
  RemoteCommand.menu: KeySequence(['82', '176']),
  RemoteCommand.playPause: KeySequence(['85']),
  RemoteCommand.input: KeySequence(['178']),
  RemoteCommand.web: KeySequence(['64']),
  RemoteCommand.netflix: AppLink('market://launch?id=com.netflix.ninja'),
  RemoteCommand.primeVideo: AppLink(
    'market://launch?id=com.amazon.avod.thirdpartyclient',
  ),
  RemoteCommand.disneyPlus: AppLink('market://launch?id=com.disney.disneyplus'),
  RemoteCommand.youtube: AppLink(
    'market://launch?id=com.google.android.youtube.tv',
  ),
};
