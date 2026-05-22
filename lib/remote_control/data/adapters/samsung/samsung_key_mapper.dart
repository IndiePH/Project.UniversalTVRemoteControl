import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_app_launch.dart';
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
    // App shortcuts launch via Tizen `ed.apps.launch` (physical keys often no-op).
    RemoteCommand.web: ['${samsungLaunchPrefix}${SamsungTizenAppIds.browser}'],
    RemoteCommand.netflix: [
      '${samsungLaunchPrefix}${SamsungTizenAppIds.netflix}',
    ],
    RemoteCommand.primeVideo: [
      '${samsungLaunchPrefix}${SamsungTizenAppIds.primeVideo}',
    ],
    RemoteCommand.disneyPlus: [
      '${samsungLaunchPrefix}${SamsungTizenAppIds.disneyPlus}',
    ],
    RemoteCommand.youtube: [
      '${samsungLaunchPrefix}${SamsungTizenAppIds.youtube}',
    ],
    RemoteCommand.dpadUp: ['KEY_UP'],
    RemoteCommand.dpadDown: ['KEY_DOWN'],
    RemoteCommand.dpadLeft: ['KEY_LEFT'],
    RemoteCommand.dpadRight: ['KEY_RIGHT'],
    RemoteCommand.dpadOk: ['KEY_ENTER'],
    RemoteCommand.back: ['KEY_RETURN'],
    RemoteCommand.home: ['KEY_HOME'],
    // Keep menu first, then try common settings/option aliases.
    RemoteCommand.menu: [
      'KEY_MENU',
      'KEY_SETTINGS',
      'KEY_SETTING',
      'KEY_OPTION',
    ],
  };

  @override
  List<String> keyCodesFor(RemoteCommand command) {
    final keyCodes = _commandToKeyCodes[command];
    if (keyCodes == null) {
      return const <String>[];
    }
    return List<String>.unmodifiable(keyCodes);
  }
}
