import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

/// Maps app-level command enums to Samsung remote key codes.
final class SamsungKeyMapper extends CommandKeyMap {
  const SamsungKeyMapper();

  static const Map<RemoteCommand, List<String>> _commandToKeyCodes = {
    RemoteCommand.power: ['KEY_POWER'],
    RemoteCommand.playPause: ['KEY_PLAYPAUSE'],
    RemoteCommand.volumeUp: ['KEY_VOLUP'],
    RemoteCommand.volumeDown: ['KEY_VOLDOWN'],
    RemoteCommand.channelUp: ['KEY_CHUP'],
    RemoteCommand.channelDown: ['KEY_CHDOWN'],
    RemoteCommand.mute: ['KEY_MUTE'],
    RemoteCommand.input: ['KEY_SOURCE'],
    // App shortcuts vary by model/firmware, so include common fallbacks.
    RemoteCommand.web: ['KEY_WWW', 'KEY_WEB_BROWSER', 'KEY_INTERNET'],
    RemoteCommand.netflix: ['KEY_NETFLIX'],
    RemoteCommand.primeVideo: ['KEY_AMAZON', 'KEY_PRIME_VIDEO'],
    RemoteCommand.disneyPlus: ['KEY_DISNEYPLUS', 'KEY_DISNEY'],
    RemoteCommand.dpadUp: ['KEY_UP'],
    RemoteCommand.dpadDown: ['KEY_DOWN'],
    RemoteCommand.dpadLeft: ['KEY_LEFT'],
    RemoteCommand.dpadRight: ['KEY_RIGHT'],
    RemoteCommand.dpadOk: ['KEY_ENTER'],
    RemoteCommand.back: ['KEY_RETURN'],
    RemoteCommand.home: ['KEY_HOME'],
    RemoteCommand.menu: ['KEY_MENU'],
  };

  String? keyCodeFor(RemoteCommand command) {
    final keyCodes = keyCodesFor(command);
    return keyCodes.isEmpty ? null : keyCodes.first;
  }

  @override
  List<String> keyCodesFor(RemoteCommand command) {
    final keyCodes = _commandToKeyCodes[command];
    if (keyCodes == null) {
      return const <String>[];
    }
    return List<String>.unmodifiable(keyCodes);
  }
}
