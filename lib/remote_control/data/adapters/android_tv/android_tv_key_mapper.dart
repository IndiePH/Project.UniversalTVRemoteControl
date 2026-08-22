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
//
// App-launch entries use https:// App Link URIs, not `market://launch?id=...`. The
// latter was an undocumented Play Store intent that Android TV/Google TV builds have
// been dropping support for; `sendAppLink` hands this string to the TV's
// `Intent.parseUri()`, and Netflix/YouTube/Prime Video/Disney+ all register native
// https intent-filters that resolve straight to the app. TclGoogleTvAdapter overrides
// these back to the legacy `market://` scheme via VariantKeyMap until that's verified
// on TCL hardware — see tcl_google_tv_adapter.dart.
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
  // Netflix does not register an app-link intent filter for the bare domain — it
  // falls through to a browser. The '/title' path is required to resolve to the app.
  RemoteCommand.netflix: AppLink('https://www.netflix.com/title'),
  RemoteCommand.primeVideo: AppLink('https://app.primevideo.com'),
  RemoteCommand.disneyPlus: AppLink('https://www.disneyplus.com'),
  RemoteCommand.youtube: AppLink('https://www.youtube.com'),
};
