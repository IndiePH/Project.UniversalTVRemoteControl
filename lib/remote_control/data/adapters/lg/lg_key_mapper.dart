import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

/// Prefix for commands routed via the webOS pointer input socket.
/// Format: `lgPointerPrefix + buttonName` — e.g. `'POINTER:UP'`.
/// [RealLgTransportClient] intercepts this prefix to use the pointer socket path.
const String lgPointerPrefix = 'POINTER:';

/// Prefix for commands that launch an app via ssap://com.webos.appmanager/launch.
/// Format: `lgLaunchPrefix + appId` — e.g. `'LAUNCH:netflix'`.
const String lgLaunchPrefix = 'LAUNCH:';

/// Sentinel for the power toggle — transport resolves to turnOn or turnOff based on tracked state.
const String lgPowerToggleKey = 'TOGGLE:POWER';

/// Sentinel for the play/pause toggle — transport resolves to play or pause based on tracked state.
const String lgPlayPauseToggleKey = 'TOGGLE:PLAY_PAUSE';

class LgKeyMapper extends CommandKeyMap {
  const LgKeyMapper();

  @override
  List<String> keyCodesFor(RemoteCommand command) {
    final code = _kLgCommandMap[command];
    return code == null ? const [] : [code];
  }
}

const Map<RemoteCommand, String> _kLgCommandMap = {
  RemoteCommand.power:       lgPowerToggleKey,
  RemoteCommand.volumeUp:    'ssap://audio/volumeUp',
  RemoteCommand.volumeDown:  'ssap://audio/volumeDown',
  RemoteCommand.mute:        'ssap://audio/setMute',
  RemoteCommand.channelUp:   'ssap://tv/channelUp',
  RemoteCommand.channelDown: 'ssap://tv/channelDown',
  RemoteCommand.home:        '${lgPointerPrefix}HOME',
  RemoteCommand.playPause:   lgPlayPauseToggleKey,
  RemoteCommand.input:       'ssap://tv/switchInput',
  RemoteCommand.netflix:     '${lgLaunchPrefix}netflix',
  RemoteCommand.primeVideo:  '${lgLaunchPrefix}amazon',
  RemoteCommand.disneyPlus:  '${lgLaunchPrefix}disneyplus',
  RemoteCommand.web:         '${lgLaunchPrefix}com.webos.app.browser',
  RemoteCommand.dpadUp:      '${lgPointerPrefix}UP',
  RemoteCommand.dpadDown:    '${lgPointerPrefix}DOWN',
  RemoteCommand.dpadLeft:    '${lgPointerPrefix}LEFT',
  RemoteCommand.dpadRight:   '${lgPointerPrefix}RIGHT',
  RemoteCommand.dpadOk:      '${lgPointerPrefix}ENTER',
  RemoteCommand.back:        '${lgPointerPrefix}BACK',
  // RemoteCommand.menu intentionally absent — no standard LG SSAP equivalent
};
