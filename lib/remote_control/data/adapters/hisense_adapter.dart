import 'dart:async';

import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class HisenseAdapter implements TvBrandAdapter {
  HisenseAdapter({required this._transportClient, CommandKeyMap? keyMap})
    : _keyMap = keyMap ?? const HisenseKeyMapper() {
    _supportedCommands = kCommonSupportedRemoteCommands
        .where((command) => _keyMap.payloadFor(command) != null)
        .toSet();
  }

  @override
  TvBrand get brand => TvBrand.hisense;

  @override
  String get protocolVariant => HisenseProtocolVariants.defaultVariant;

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      const TvDeviceInfo();

  @override
  bool get supportsTextInput => _isTextInputEnabled;

  @override
  Set<RemoteCommand> get supportedCommands => _supportedCommands;

  final HisenseTransportClient _transportClient;
  final CommandKeyMap _keyMap;
  late final Set<RemoteCommand> _supportedCommands;
  final Map<String, Future<void>> _connectInFlight = {};
  static const bool _isTextInputEnabled = bool.fromEnvironment(
    'HISENSE_ENABLE_TEXT_INPUT',
    defaultValue: false,
  );

  @override
  Future<void> probeConnection({required TvDevice device}) async {
    await _transportClient.probe(device.resolvedHost);
  }

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    // Clears persisted per-host PIN authorization so the next pair attempt
    // re-enters the PIN gate.
    await _transportClient.clearPairing(deviceId: device.id);
  }

  @override
  Future<void> cancelPairing({required TvDevice device}) async {}

  @override
  Future<void> preparePairing({required TvDevice device}) async {
    await _transportClient.connect(deviceId: device.id);
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
    await _transportClient.submitAuthenticationCode(
      deviceId: device.id,
      fourDigitPin: pinCode,
    );
    // Reconnect immediately so the transport publishes a fresh connected state
    // after PIN acceptance instead of waiting for the next user command.
    await _transportClient.connect(deviceId: device.id);
  }

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final payload = _keyMap.payloadFor(command);
    if (payload == null) {
      throw UnsupportedError('No Hisense mapping for command: $command');
    }
    await _transportClient.connect(deviceId: device.id);
    switch (payload) {
      case KeySequence(:final codes):
        // VIDAA firmwares vary in which key alias they recognize for a given
        // logical command (e.g. KEY_RETURNS vs KEY_RETURN vs KEY_BACK). MQTT
        // sendkey is fire-and-forget atMostOnce with no per-key ack channel, so
        // we publish each known alias in order; the TV silently ignores aliases
        // it does not recognize and acts on the one it does.
        for (final code in codes) {
          await _transportClient.sendKey(deviceId: device.id, keyName: code);
        }
      case AppLink():
        throw UnsupportedError('Hisense has no AppLink dispatch path.');
      case VidaaLaunch(:final displayName, :final url):
        await _transportClient.launchVidaaApp(
          deviceId: device.id,
          displayName: displayName,
          url: url,
        );
    }
  }

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) async* {
    try {
      await connect(device: device);
    } catch (_) {
      yield ConnectionState.error;
      return;
    }
    yield* _transportClient.watchConnectionState(device.id);
  }

  /// Text input remains validation-gated for Hisense; keep disabled by default
  /// until physical hardware confirms the selected transport contract.
  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    if (!_isTextInputEnabled) {
      throw UnsupportedError(
        'Hisense text input is validation-gated. Enable '
        'HISENSE_ENABLE_TEXT_INPUT only after physical-device validation.',
      );
    }
    await _transportClient.sendText(deviceId: device.id, text: text);
  }
}
