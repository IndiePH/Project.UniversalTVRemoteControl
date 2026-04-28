import 'dart:async';
import 'dart:developer';

import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';

/// Logs calls for tests and offline development.
class FakeHisenseTransportClient
    with TransportEventEmitterMixin
    implements HisenseTransportClient {
  final Set<String> _connected = <String>{};
  final Set<String> _authorized = <String>{};
  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      <String, StreamController<ConnectionState>>{};
  final Map<String, ConnectionState> _lastConnectionStates =
      <String, ConnectionState>{};

  @override
  Future<void> connect({required String deviceId}) async {
    _emitConnectionState(deviceId, ConnectionState.connecting);
    _connected.add(deviceId);
    _emitConnectionState(deviceId, ConnectionState.connected);
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
    log(
      'Hisense MQTT sendkey: $deviceId -> $keyName',
      name: 'hisense_transport',
    );
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

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _connectionControllerFor(deviceId).stream;

  Future<void> _ensure(String deviceId) async {
    if (!_connected.contains(deviceId)) {
      _connected.add(deviceId);
      log('Hisense MQTT connect: $deviceId', name: 'hisense_transport');
    }
  }

  StreamController<ConnectionState> _connectionControllerFor(String deviceId) {
    return _connectionControllers.putIfAbsent(
      deviceId,
      () => StreamController<ConnectionState>.broadcast(
        onListen: () {
          _connectionControllers[deviceId]?.add(
            _lastConnectionStates[deviceId] ?? ConnectionState.disconnected,
          );
        },
      ),
    );
  }

  void _emitConnectionState(String deviceId, ConnectionState state) {
    if (_lastConnectionStates[deviceId] == state) {
      return;
    }
    _lastConnectionStates[deviceId] = state;
    final ctrl = _connectionControllers[deviceId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(state);
    }
  }
}
