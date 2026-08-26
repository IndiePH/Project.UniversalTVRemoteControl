import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

/// App id for LG's settings app, launched as the second of [RemoteCommand.menu]'s two
/// unconditional actions. Not a [_payloads] entry of its own — see [LgAdapter.sendCommand]'s
/// menu special case for why menu isn't expressed as a single [CommandPayload].
const String lgSettingsAppId = 'com.webos.app.settings';

class LgKeyMapper extends CommandKeyMap {
  const LgKeyMapper();

  @override
  CommandPayload? payloadFor(RemoteCommand command) => _payloads[command];
}

const Map<RemoteCommand, CommandPayload> _payloads = {
  RemoteCommand.power: ToggleCommand(ToggleKind.power),
  RemoteCommand.volumeUp: KeySequence(['ssap://audio/volumeUp']),
  RemoteCommand.volumeDown: KeySequence(['ssap://audio/volumeDown']),
  RemoteCommand.mute: ToggleCommand(ToggleKind.mute),
  RemoteCommand.channelUp: KeySequence(['ssap://tv/channelUp']),
  RemoteCommand.channelDown: KeySequence(['ssap://tv/channelDown']),
  RemoteCommand.home: PointerCommand('HOME'),
  RemoteCommand.playPause: ToggleCommand(ToggleKind.playPause),
  RemoteCommand.input: KeySequence(['ssap://tv/switchInput']),
  RemoteCommand.dpadUp: PointerCommand('UP'),
  RemoteCommand.dpadDown: PointerCommand('DOWN'),
  RemoteCommand.dpadLeft: PointerCommand('LEFT'),
  RemoteCommand.dpadRight: PointerCommand('RIGHT'),
  RemoteCommand.dpadOk: PointerCommand('ENTER'),
  RemoteCommand.back: PointerCommand('BACK'),
  // The settings-app launch (lgSettingsAppId) is dispatched separately by
  // LgAdapter.sendCommand's menu special case — both actions are unconditional
  // and deliberate (git blame: added together to cover different webOS build
  // variants), not a primary/fallback pair.
  RemoteCommand.menu: KeySequence([
    'ssap://com.webos.service.settings/launchSettings',
  ]),
  RemoteCommand.netflix: AppLink('netflix'),
  RemoteCommand.primeVideo: AppLink('amazon'),
  RemoteCommand.disneyPlus: AppLink('disneyplus'),
  RemoteCommand.youtube: AppLink('youtube.leanback.v4'),
  RemoteCommand.web: AppLink('com.webos.app.browser'),
};
