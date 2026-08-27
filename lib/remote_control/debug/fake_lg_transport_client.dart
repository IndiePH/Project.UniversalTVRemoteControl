import 'dart:async';
import 'dart:developer';

import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';

/// Test double for [LgTransportClient].
///
/// All methods complete without throwing. [requestClientKey] returns a
/// deterministic fake key immediately. Mirrors [FakeSamsungTransportClient].
class FakeLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  final Set<String> _connected = {};
  final Map<String, StreamController<LgRegistrationState>>
  _registrationControllers = {};
  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      {};
  final Map<String, ConnectionState> _lastConnectionStates = {};

  @override
  Future<void> connect({required String deviceId}) async {
    _emitConnectionState(deviceId, ConnectionState.connecting);
    _connected.add(deviceId);
    _emitRegistrationState(deviceId, LgRegistrationState.registered);
    _emitConnectionState(deviceId, ConnectionState.connected);
    emitTransportEvent(
      TransportEvent(transport: 'lg', deviceId: deviceId, type: 'connected'),
    );
    log('LG fake transport connected: $deviceId', name: 'lg_transport');
  }

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await _ensureConnected(deviceId);
    return 'fake-client-key-$deviceId';
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    await _ensureConnected(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'lg',
        deviceId: deviceId,
        type: 'key_sent',
        message: keyCode,
      ),
    );
    log(
      'LG fake transport sendKey: $deviceId -> $keyCode',
      name: 'lg_transport',
    );
  }

  @override
  Future<void> sendPointerCommand({
    required String deviceId,
    required String button,
  }) async {
    await _ensureConnected(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'lg',
        deviceId: deviceId,
        type: 'pointer_sent',
        message: button,
      ),
    );
    log(
      'LG fake transport sendPointerCommand: $deviceId -> $button',
      name: 'lg_transport',
    );
  }

  @override
  Future<void> sendAppLink({
    required String deviceId,
    required String appLink,
  }) async {
    await _ensureConnected(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'lg',
        deviceId: deviceId,
        type: 'app_link_sent',
        message: appLink,
      ),
    );
    log(
      'LG fake transport sendAppLink: $deviceId -> $appLink',
      name: 'lg_transport',
    );
  }

  @override
  Future<void> sendToggle({
    required String deviceId,
    required ToggleKind kind,
  }) async {
    await _ensureConnected(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'lg',
        deviceId: deviceId,
        type: 'toggle_sent',
        message: kind.name,
      ),
    );
    log(
      'LG fake transport sendToggle: $deviceId -> ${kind.name}',
      name: 'lg_transport',
    );
  }

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {
    await _ensureConnected(deviceId);
    emitTransportEvent(
      TransportEvent(transport: 'lg', deviceId: deviceId, type: 'text_sent'),
    );
    log(
      'LG fake transport sendText: $deviceId -> "$text"',
      name: 'lg_transport',
    );
  }

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      _registrationControllerFor(deviceId).stream;

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _connectionControllerFor(deviceId).stream;

  @override
  Future<Map<String, dynamic>?> querySystemInfo({
    required String deviceId,
  }) async {
    await _ensureConnected(deviceId);
    return const {
      'modelName': 'FAKE-LG-TV',
      'version': '0.0.0',
      'returnValue': true,
    };
  }

  @override
  Future<void> disconnect({required String deviceId}) async {
    _connected.remove(deviceId);
    _emitRegistrationState(deviceId, LgRegistrationState.failed);
    _emitConnectionState(deviceId, ConnectionState.disconnected);
    log('LG fake transport disconnected: $deviceId', name: 'lg_transport');
  }

  @override
  Future<void> clearPairing({required String deviceId}) async {
    await disconnect(deviceId: deviceId);
  }

  @override
  void cancelPairing(String deviceId) {}

  @override
  Future<void> probe(String host) async {}

  Future<void> _ensureConnected(String deviceId) async {
    if (!_connected.contains(deviceId)) await connect(deviceId: deviceId);
  }

  StreamController<LgRegistrationState> _registrationControllerFor(
    String deviceId,
  ) {
    return _registrationControllers.putIfAbsent(
      deviceId,
      () => StreamController<LgRegistrationState>.broadcast(),
    );
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

  void _emitRegistrationState(String deviceId, LgRegistrationState state) {
    final ctrl = _registrationControllers[deviceId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(state);
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
