import 'package:one_remote/src/features/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';

/// Maps [RemoteCommand] values to VIDAA MQTT `sendkey` key names.
///
/// See: community MQTT docs for Hisense VIDAA (`KEY_*` strings).
final class HisenseKeyMapper extends CommandKeyMap {
  const HisenseKeyMapper();

  static const Map<RemoteCommand, List<String>> _commandToKeyNames = {
    RemoteCommand.power: ['KEY_POWER'],
    // Many builds expose either a combined code or separate play/pause.
    RemoteCommand.playPause: ['KEY_PLAYPAUSE', 'KEY_PLAY'],
    RemoteCommand.volumeUp: ['KEY_VOLUMEUP'],
    RemoteCommand.volumeDown: ['KEY_VOLUMEDOWN'],
    RemoteCommand.channelUp: ['KEY_CHANNELUP', 'KEY_CHSUP'],
    RemoteCommand.channelDown: ['KEY_CHANNELDOWN', 'KEY_CHSDOWN'],
    RemoteCommand.mute: ['KEY_MUTE'],
    RemoteCommand.input: ['KEY_SOURCE', 'KEY_INPUT'],
    RemoteCommand.dpadUp: ['KEY_UP'],
    RemoteCommand.dpadDown: ['KEY_DOWN'],
    RemoteCommand.dpadLeft: ['KEY_LEFT'],
    RemoteCommand.dpadRight: ['KEY_RIGHT'],
    RemoteCommand.dpadOk: ['KEY_OK'],
    // README uses KEY_RETURNS for back on some firmwares.
    RemoteCommand.back: ['KEY_RETURNS', 'KEY_RETURN', 'KEY_BACK'],
    RemoteCommand.home: ['KEY_HOME'],
    RemoteCommand.menu: ['KEY_MENU'],
    // Handled via [HisenseAdapter] launch-app MQTT, not sendkey.
    RemoteCommand.web: [],
    RemoteCommand.netflix: [],
    RemoteCommand.primeVideo: [],
    RemoteCommand.disneyPlus: [],
  };

  @override
  List<String> keyCodesFor(RemoteCommand command) {
    final keys = _commandToKeyNames[command];
    if (keys == null) {
      return const <String>[];
    }
    return List<String>.unmodifiable(keys);
  }
}
