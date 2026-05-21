import 'dart:async';

import 'package:one_remote/remote_control/data/adapters/tcl/roku_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class FakeRokuTransportClient
    with TransportEventEmitterMixin
    implements RokuTransportClient {
  final Set<String> _connected = <String>{};
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
      TransportEvent(transport: 'roku', deviceId: deviceId, type: 'connected'),
    );
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    await _ensureConnected(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'roku',
        deviceId: deviceId,
        type: 'key_sent',
        message: keyCode,
      ),
    );
  }

  @override
  Future<void> launchApp({
    required String deviceId,
    required String appId,
  }) async {
    await _ensureConnected(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'roku',
        deviceId: deviceId,
        type: 'app_launched',
        message: appId,
      ),
    );
  }

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId}) async {
    await _ensureConnected(deviceId);
    return const TvDeviceInfo(modelIdentifier: 'roku');
  }

  @override
  Future<void> probe(String host) async {}

  @override
  Future<void> clearPairing({required String deviceId}) async {
    _connected.remove(deviceId);
    _emitConnectionState(deviceId, ConnectionState.disconnected);
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _connectionControllerFor(deviceId).stream;

  Future<void> _ensureConnected(String deviceId) async {
    if (_connected.contains(deviceId)) {
      return;
    }
    await connect(deviceId: deviceId);
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
