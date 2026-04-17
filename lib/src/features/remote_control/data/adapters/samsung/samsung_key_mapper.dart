import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/remote_command.dart';

/// Maps app-level command enums to Samsung remote key codes.
final class SamsungKeyMapper {
  const SamsungKeyMapper();

  static const Map<RemoteCommand, String> _commandToKeyCode = {
    RemoteCommand.power: 'KEY_POWER',
    RemoteCommand.playPause: 'KEY_PLAYPAUSE',
    RemoteCommand.volumeUp: 'KEY_VOLUP',
    RemoteCommand.volumeDown: 'KEY_VOLDOWN',
    RemoteCommand.channelUp: 'KEY_CHUP',
    RemoteCommand.channelDown: 'KEY_CHDOWN',
    RemoteCommand.mute: 'KEY_MUTE',
    RemoteCommand.input: 'KEY_SOURCE',
    RemoteCommand.web: 'KEY_WWW',
    RemoteCommand.netflix: 'KEY_NETFLIX',
    RemoteCommand.primeVideo: 'KEY_AMAZON',
    RemoteCommand.disneyPlus: 'KEY_DISNEYPLUS',
    RemoteCommand.dpadUp: 'KEY_UP',
    RemoteCommand.dpadDown: 'KEY_DOWN',
    RemoteCommand.dpadLeft: 'KEY_LEFT',
    RemoteCommand.dpadRight: 'KEY_RIGHT',
    RemoteCommand.dpadOk: 'KEY_ENTER',
    RemoteCommand.back: 'KEY_RETURN',
    RemoteCommand.home: 'KEY_HOME',
    RemoteCommand.menu: 'KEY_MENU',
  };

  String? keyCodeFor(RemoteCommand command) => _commandToKeyCode[command];
}
