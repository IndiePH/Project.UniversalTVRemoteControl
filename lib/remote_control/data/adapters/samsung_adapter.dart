import 'dart:async';

import 'package:one_remote/remote_control/application/transport_log_provider.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_authorization.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_log_reader.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class SamsungAdapter implements TvBrandAdapter, TransportLogProvider {
  SamsungAdapter({required this._transportClient, CommandKeyMap? keyMapper})
    : _keyMapper = keyMapper ?? const SamsungKeyMapper() {
    _supportedCommands = kCommonSupportedRemoteCommands
        .where((command) => _keyMapper.payloadFor(command) != null)
        .toSet();
  }

  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  String get protocolVariant => SamsungProtocolVariants.defaultVariant;

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async {
    final cached = _transportClient.getCachedDeviceInfo(device.id);
    if (cached != null) {
      return cached;
    }
    try {
      await _transportClient.connect(deviceId: device.id);
    } catch (_) {
      // Debug probe only; cache may still be empty if TV did not connect.
    }
    return _transportClient.getCachedDeviceInfo(device.id);
  }

  @override
  TransportLogReader get transportLogReader =>
      const SamsungTransportLogReader();

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => _supportedCommands;

  final SamsungTransportClient _transportClient;
  final CommandKeyMap _keyMapper;
  late final Set<RemoteCommand> _supportedCommands;
  final Map<String, Future<void>> _connectInFlight = {};

  static final _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');

  @override
  Future<void> probeConnection({required TvDevice device}) async {
    final host = _ipv4.firstMatch(device.id)?.group(1) ?? '';
    await _transportClient.probe(host);
  }

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    await _transportClient.clearPairing(deviceId: device.id);
  }

  @override
  Future<void> cancelPairing({required TvDevice device}) async =>
      _transportClient.cancelPairing(device.id);

  @override
  Future<void> preparePairing({required TvDevice device}) async {
    final backPayload = _keyMapper.payloadFor(RemoteCommand.back);
    final triggerKeyCode =
        backPayload is KeySequence && backPayload.codes.isNotEmpty
        ? backPayload.codes.first
        : 'KEY_RETURN';
    await _transportClient.requestPairingApproval(
      deviceId: device.id,
      triggerKeyCode: triggerKeyCode,
    );
  }

  @override
  Future<void> connect({required TvDevice device}) {
    return _connectInFlight.putIfAbsent(device.id, () {
      final f = _transportClient.connect(deviceId: device.id);
      f.whenComplete(() => _connectInFlight.remove(device.id)).ignore();
      return f;
    });
  }

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String pinCode,
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
    final payload = _keyMapper.payloadFor(command);
    if (payload == null) {
      throw UnsupportedError('No Samsung key mapping for command: $command');
    }
    await _transportClient.connect(deviceId: device.id);
    switch (payload) {
      case KeySequence(:final codes):
        for (final code in codes) {
          await _transportClient.sendKey(deviceId: device.id, keyCode: code);
        }
      case AppLink(:final uri):
        await _transportClient.launchApp(deviceId: device.id, appId: uri);
      case VidaaLaunch():
        throw UnsupportedError('Samsung has no VidaaLaunch dispatch path.');
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
      return await _transportClient.probeRemoteTextInputReady(
        deviceId: device.id,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) async* {
    try {
      await connect(device: device);
    } catch (error) {
      yield SamsungTransportAuthorization.isAuthorizationError(error)
          ? ConnectionState.unauthorized
          : ConnectionState.error;
      return;
    }
    yield* _transportClient.watchConnectionState(device.id);
  }
}
