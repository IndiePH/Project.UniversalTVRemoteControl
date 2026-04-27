import 'package:one_remote/remote_control/application/transport_log_provider.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_log_reader.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class SamsungAdapter implements TvBrandAdapter, TransportLogProvider {
  SamsungAdapter({
    required SamsungTransportClient transportClient,
    CommandKeyMap? keyMapper,
  }) : _transportClient = transportClient,
       _keyMapper = keyMapper ?? const SamsungKeyMapper();

  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  String get protocolVariant => SamsungProtocolVariants.defaultVariant;

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      const TvDeviceInfo();

  @override
  TransportLogReader get transportLogReader =>
      const SamsungTransportLogReader();

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands;

  final SamsungTransportClient _transportClient;
  final CommandKeyMap _keyMapper;

  static final _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');

  @override
  Future<void> probeConnection({required TvDevice device}) async {
    final host = _ipv4.firstMatch(device.id)?.group(1) ?? '';
    await _transportClient.probe(host);
  }

  @override
  // TODO(unpair): Samsung has no persistent pairing state yet, so nothing to clear.
  // When Samsung token/session persistence is added, follow the SharedPreferences
  // pattern in LgPairingKeyStore + LgWebSocketTransportClient.clearPairing.
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<void> preparePairing({required TvDevice device}) async {
    final keyCodes = _keyMapper.keyCodesFor(RemoteCommand.back);
    final triggerKeyCode = keyCodes.isNotEmpty ? keyCodes.first : 'KEY_RETURN';
    await _transportClient.requestPairingApproval(
      deviceId: device.id,
      triggerKeyCode: triggerKeyCode,
    );
  }

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    throw UnsupportedError(
      'Samsung pairing code submission is not required in this flow.',
    );
  }

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final keyCodes = _keyMapper.keyCodesFor(command);
    if (keyCodes.isEmpty) {
      throw UnsupportedError('No Samsung key mapping for command: $command');
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
  Stream<bool> watchRemoteTextInputReady(TvDevice device) async* {
    try {
      await _transportClient.connect(deviceId: device.id);
    } catch (_) {
      yield false;
      return;
    }
    yield* _transportClient.watchRemoteTextInputReady(device.id);
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
