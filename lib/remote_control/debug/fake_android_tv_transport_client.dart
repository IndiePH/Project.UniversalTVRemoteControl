import 'dart:async';
import 'dart:developer';

import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class FakeAndroidTvTransportClient
    with TransportEventEmitterMixin
    implements AndroidTvTransportClient {
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
      TransportEvent(
        transport: 'android_tv',
        deviceId: deviceId,
        type: 'connected',
      ),
    );
    log(
      'Android TV fake transport connected: $deviceId',
      name: 'android_tv_transport',
    );
  }

  @override
  Future<void> submitPairingCode({
    required String deviceId,
    required String code,
  }) async {
    await _ensureConnected(deviceId);
    log(
      'Android TV fake transport submitPairingCode: $deviceId code=$code',
      name: 'android_tv_transport',
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
        transport: 'android_tv',
        deviceId: deviceId,
        type: 'key_sent',
        message: keyCode,
      ),
    );
    log(
      'Android TV fake transport sendKey: $deviceId -> $keyCode',
      name: 'android_tv_transport',
    );
  }

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {
    await _ensureConnected(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'android_tv',
        deviceId: deviceId,
        type: 'text_sent',
      ),
    );
    log(
      'Android TV fake transport sendText: $deviceId -> "$text"',
      name: 'android_tv_transport',
    );
  }

  @override
  Future<void> probe(String host) async {}

  @override
  Future<void> clearPairing({required String deviceId}) async {
    _connected.remove(deviceId);
    _emitConnectionState(deviceId, ConnectionState.disconnected);
    log(
      'Android TV fake transport clearPairing: $deviceId',
      name: 'android_tv_transport',
    );
  }

  @override
  void cancelPairing(String deviceId) {}

  @override
  Future<TvDeviceInfo> queryDeviceInfo({required String deviceId}) async {
    await _ensureConnected(deviceId);
    return const TvDeviceInfo();
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _connectionControllerFor(deviceId).stream;

  Future<void> _ensureConnected(String deviceId) async {
    if (!_connected.contains(deviceId)) await connect(deviceId: deviceId);
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
    if (_lastConnectionStates[deviceId] == state) return;
    _lastConnectionStates[deviceId] = state;
    final ctrl = _connectionControllers[deviceId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(state);
  }
}
