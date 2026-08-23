import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

// TCL's Google TV builds have not been verified against the https:// App Link URIs
// used by AndroidTvKeyMapper's default map (see android_tv_key_mapper.dart) — until
// confirmed on hardware, these four commands keep the legacy `market://launch?id=...`
// behavior TCL devices previously relied on.
const _tclLegacyAppLinkOverrides = <RemoteCommand, CommandPayload>{
  RemoteCommand.netflix: AppLink('market://launch?id=com.netflix.ninja'),
  RemoteCommand.primeVideo: AppLink(
    'market://launch?id=com.amazon.avod.thirdpartyclient',
  ),
  RemoteCommand.disneyPlus: AppLink('market://launch?id=com.disney.disneyplus'),
  RemoteCommand.youtube: AppLink(
    'market://launch?id=com.google.android.youtube.tv',
  ),
};

class TclGoogleTvAdapter implements TvBrandAdapter {
  TclGoogleTvAdapter({required this._transportClient, CommandKeyMap? keyMap})
    : _keyMap =
          keyMap ??
          const VariantKeyMap(
            AndroidTvKeyMapper(),
            _tclLegacyAppLinkOverrides,
          ) {
    _supportedCommands = kCommonSupportedRemoteCommands
        .where((command) => _keyMap.payloadFor(command) != null)
        .toSet();
  }

  final AndroidTvTransportClient _transportClient;
  final CommandKeyMap _keyMap;
  late final Set<RemoteCommand> _supportedCommands;

  @override
  TvBrand get brand => TvBrand.tcl;

  @override
  String get protocolVariant => TclProtocolVariants.googleTv;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => _supportedCommands;

  @override
  Future<void> probeConnection({required TvDevice device}) async {
    await _transportClient.probe(device.resolvedHost);
  }

  @override
  Future<void> preparePairing({required TvDevice device}) =>
      _transportClient.connect(deviceId: device.id);

  @override
  Future<void> connect({required TvDevice device}) =>
      _transportClient.connect(deviceId: device.id);

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) => _transportClient.submitPairingCode(deviceId: device.id, code: pinCode);

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async {
    final info = await _transportClient.queryDeviceInfo(deviceId: device.id);
    return TvDeviceInfo(
      modelIdentifier: 'tcl_google_tv',
      firmwareVersion: info.firmwareVersion,
    );
  }

  @override
  Future<void> unpairDevice({required TvDevice device}) =>
      _transportClient.clearPairing(deviceId: device.id);

  @override
  Future<void> cancelPairing({required TvDevice device}) async =>
      _transportClient.cancelPairing(device.id);

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    await _transportClient.connect(deviceId: device.id);
    final payload = _keyMap.payloadFor(command);
    if (payload == null) {
      throw UnsupportedError(
        'No TCL Google TV key mapping for command: $command',
      );
    }
    switch (payload) {
      case KeySequence(:final codes):
        for (final code in codes) {
          await _transportClient.sendKey(deviceId: device.id, keyCode: code);
        }
      case AppLink(:final uri):
        await _transportClient.sendAppLink(deviceId: device.id, appLink: uri);
      case VidaaLaunch():
        throw UnsupportedError(
          'TCL Google TV has no VidaaLaunch dispatch path.',
        );
    }
  }

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    await _transportClient.connect(deviceId: device.id);
    await _transportClient.sendText(deviceId: device.id, text: text);
  }

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  Future<bool> probeRemoteTextInputReady({required TvDevice device}) async {
    await _transportClient.connect(deviceId: device.id);
    return true;
  }

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      _transportClient.watchConnectionState(device.id);
}
