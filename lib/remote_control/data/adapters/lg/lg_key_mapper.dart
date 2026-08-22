import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

/// Prefix for commands routed via the webOS pointer input socket.
/// Format: `lgPointerPrefix + buttonName` — e.g. `'POINTER:UP'`.
/// [RealLgTransportClient] intercepts this prefix to use the pointer socket path.
const String lgPointerPrefix = 'POINTER:';

/// Prefix for commands that launch an app via ssap://com.webos.appmanager/launch.
/// Format: `lgLaunchPrefix + appId` — e.g. `'LAUNCH:netflix'`.
///
/// Every LG command dispatches via `sendKey`, including the five app-launch
/// commands below — `menu`'s settings-app fallback also relies on this same
/// sentinel, so `LgWebSocketTransportClient`'s `sendKey`-path `startsWith` check
/// can't be removed. Since that branch has to stay regardless, the app-launch
/// commands keep using it too rather than gaining a separate direct-dispatch
/// method that would just duplicate the same underlying SSAP call. See
/// `references/goals/goal-app-launch-dispatch-unification.md` Phase 3.
const String lgLaunchPrefix = 'LAUNCH:';

/// Sentinel for the power toggle — transport resolves to turnOn or turnOff based on tracked state.
const String lgPowerToggleKey = 'TOGGLE:POWER';

/// Sentinel for the play/pause toggle — transport resolves to play or pause based on tracked state.
const String lgPlayPauseToggleKey = 'TOGGLE:PLAY_PAUSE';

class LgKeyMapper extends CommandKeyMap {
  const LgKeyMapper();

  @override
  CommandPayload? payloadFor(RemoteCommand command) => _payloads[command];
}

const Map<RemoteCommand, CommandPayload> _payloads = {
  RemoteCommand.power: KeySequence([lgPowerToggleKey]),
  RemoteCommand.volumeUp: KeySequence(['ssap://audio/volumeUp']),
  RemoteCommand.volumeDown: KeySequence(['ssap://audio/volumeDown']),
  RemoteCommand.mute: KeySequence(['ssap://audio/setMute']),
  RemoteCommand.channelUp: KeySequence(['ssap://tv/channelUp']),
  RemoteCommand.channelDown: KeySequence(['ssap://tv/channelDown']),
  RemoteCommand.home: KeySequence(['${lgPointerPrefix}HOME']),
  RemoteCommand.playPause: KeySequence([lgPlayPauseToggleKey]),
  RemoteCommand.input: KeySequence(['ssap://tv/switchInput']),
  RemoteCommand.dpadUp: KeySequence(['${lgPointerPrefix}UP']),
  RemoteCommand.dpadDown: KeySequence(['${lgPointerPrefix}DOWN']),
  RemoteCommand.dpadLeft: KeySequence(['${lgPointerPrefix}LEFT']),
  RemoteCommand.dpadRight: KeySequence(['${lgPointerPrefix}RIGHT']),
  RemoteCommand.dpadOk: KeySequence(['${lgPointerPrefix}ENTER']),
  RemoteCommand.back: KeySequence(['${lgPointerPrefix}BACK']),
  // menu behavior varies by webOS build; try settings entry points in order.
  RemoteCommand.menu: KeySequence([
    'ssap://com.webos.service.settings/launchSettings',
    '${lgLaunchPrefix}com.webos.app.settings',
  ]),
  // Dispatched via `sendKey`, same as every other command — the LAUNCH: sentinel
  // is interpreted by LgWebSocketTransportClient's command factory (see
  // lgLaunchPrefix's doc comment above for why this stays KeySequence instead of
  // becoming a direct-dispatch AppLink like Samsung's equivalent commands).
  RemoteCommand.netflix: KeySequence(['${lgLaunchPrefix}netflix']),
  RemoteCommand.primeVideo: KeySequence(['${lgLaunchPrefix}amazon']),
  RemoteCommand.disneyPlus: KeySequence(['${lgLaunchPrefix}disneyplus']),
  RemoteCommand.youtube: KeySequence(['${lgLaunchPrefix}youtube.leanback.v4']),
  RemoteCommand.web: KeySequence(['${lgLaunchPrefix}com.webos.app.browser']),
};
