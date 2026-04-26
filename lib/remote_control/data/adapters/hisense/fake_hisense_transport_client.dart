import 'dart:developer';

import 'package:one_remote/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';

/// Logs calls for tests and offline development.
class FakeHisenseTransportClient
    with TransportEventEmitterMixin
    implements HisenseTransportClient {
  final Set<String> _connected = <String>{};
  final Set<String> _authorized = <String>{};

  @override
  Future<void> connect({required String deviceId}) async {
    _connected.add(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'hisense',
        deviceId: deviceId,
        type: 'connected',
      ),
    );
    log('Hisense MQTT connect: $deviceId', name: 'hisense_transport');
    if (!_authorized.contains(deviceId)) {
      throw StateError(
        'Hisense pairing requires a 4-digit code shown on TV. Enter it to continue.',
      );
    }
  }

  @override
  Future<void> submitAuthenticationCode({
    required String deviceId,
    required String fourDigitPin,
  }) async {
    await _ensure(deviceId);
    final pin = fourDigitPin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw StateError('Pairing code must be exactly 4 digits.');
    }
    if (pin != '1234') {
      throw StateError('Incorrect pairing code. Please try again.');
    }
    _authorized.add(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'hisense',
        deviceId: deviceId,
        type: 'authentication_code_submitted',
      ),
    );
    log(
      'Hisense MQTT auth: $deviceId pin=$fourDigitPin',
      name: 'hisense_transport',
    );
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyName,
  }) async {
    await _ensure(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'hisense',
        deviceId: deviceId,
        type: 'key_sent',
        message: keyName,
      ),
    );
    log('Hisense MQTT sendkey: $deviceId -> $keyName', name: 'hisense_transport');
  }

  @override
  Future<void> launchVidaaApp({
    required String deviceId,
    required String displayName,
    required String url,
    int urlType = 37,
    int storeType = 0,
  }) async {
    await _ensure(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'hisense',
        deviceId: deviceId,
        type: 'app_launched',
        message: displayName,
      ),
    );
    log(
      'Hisense MQTT launchapp: $deviceId name=$displayName url=$url '
      'urlType=$urlType storeType=$storeType',
      name: 'hisense_transport',
    );
  }

  @override
  Future<void> probe(String host) async {}

  Future<void> _ensure(String deviceId) async {
    if (!_connected.contains(deviceId)) {
      _connected.add(deviceId);
      log('Hisense MQTT connect: $deviceId', name: 'hisense_transport');
    }
  }
}
