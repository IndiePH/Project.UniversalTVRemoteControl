import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class LgAdapter implements TvBrandAdapter {
  LgAdapter({required this._transportClient, CommandKeyMap? keyMap})
    : _keyMap = keyMap ?? const LgKeyMapper();

  @override
  TvBrand get brand => TvBrand.lg;

  @override
  String get protocolVariant => LgProtocolVariants.defaultVariant;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands;

  final LgTransportClient _transportClient;
  final CommandKeyMap _keyMap;

  static final _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');

  @override
  Future<void> probeConnection({required TvDevice device}) async {
    final host = _ipv4.firstMatch(device.id)?.group(1) ?? '';
    await _transportClient.probe(host);
  }

  @override
  Future<void> preparePairing({required TvDevice device}) async {
    await _transportClient.connect(deviceId: device.id);
    await _transportClient.requestClientKey(deviceId: device.id);
  }

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async {
    final raw = await _transportClient.querySystemInfo(deviceId: device.id);
    if (raw == null) return const TvDeviceInfo();
    return TvDeviceInfo(
      modelIdentifier: raw['modelName'] as String?,
      firmwareVersion: raw['swVersion'] as String?,
    );
  }

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    await _transportClient.clearPairing(deviceId: device.id);
  }

  @override
  Future<void> cancelPairing({required TvDevice device}) async =>
      _transportClient.cancelPairing(device.id);

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async {
    throw UnsupportedError('LG uses a client-key flow, not a PIN code.');
  }

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final keyCodes = _keyMap.keyCodesFor(command);
    if (keyCodes.isEmpty) {
      throw UnsupportedError('No LG key mapping for command: $command');
    }
    await _transportClient.connect(deviceId: device.id);
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
      _transportClient.watchRemoteTextInputReady(device.id);

  Future<bool> probeRemoteTextInputReady({required TvDevice device}) async {
    try {
      await _transportClient.connect(deviceId: device.id);
      return await _transportClient
          .watchRemoteTextInputReady(device.id)
          .first
          .timeout(const Duration(milliseconds: 750), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) async* {
    try {
      await _transportClient.connect(deviceId: device.id);
    } catch (_) {
      yield ConnectionState.error;
      return;
    }
    yield* _transportClient.watchConnectionState(device.id);
  }
}
