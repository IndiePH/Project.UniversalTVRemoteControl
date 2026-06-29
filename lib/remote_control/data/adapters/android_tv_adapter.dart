import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class AndroidTvAdapter implements TvBrandAdapter {
  AndroidTvAdapter({
    required this._transportClient,
    CommandKeyMap? keyMap,
  }) : _keyMap = keyMap ?? const AndroidTvKeyMapper();

  @override
  TvBrand get brand => TvBrand.androidTv;

  @override
  String get protocolVariant => AndroidTvProtocolVariants.defaultVariant;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands;

  final AndroidTvTransportClient _transportClient;
  final CommandKeyMap _keyMap;

  static final _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');

  @override
  Future<void> probeConnection({required TvDevice device}) async {
    final host = _ipv4.firstMatch(device.id)?.group(1) ?? '';
    await _transportClient.probe(host);
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
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) =>
      _transportClient.queryDeviceInfo(deviceId: device.id);

  @override
  Future<void> unpairDevice({required TvDevice device}) =>
      _transportClient.clearPairing(deviceId: device.id);

  @override
  Future<void> cancelPairing({required TvDevice device}) async =>
      _transportClient.cancelPairing(device.id);

  static const Map<RemoteCommand, String> _appLinks = {
    RemoteCommand.netflix: 'market://launch?id=com.netflix.ninja',
    RemoteCommand.primeVideo:
        'market://launch?id=com.amazon.avod.thirdpartyclient',
    RemoteCommand.disneyPlus: 'market://launch?id=com.disney.disneyplus',
    RemoteCommand.youtube: 'market://launch?id=com.google.android.youtube.tv',
  };

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    await _transportClient.connect(deviceId: device.id);
    final appLink = _appLinks[command];
    if (appLink != null) {
      await _transportClient.sendAppLink(deviceId: device.id, appLink: appLink);
      return;
    }
    final keyCodes = _keyMap.keyCodesFor(command);
    if (keyCodes.isEmpty) {
      throw UnsupportedError('No Android TV key mapping for command: $command');
    }
    for (final keyCode in keyCodes) {
      await _transportClient.sendKey(deviceId: device.id, keyCode: keyCode);
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
