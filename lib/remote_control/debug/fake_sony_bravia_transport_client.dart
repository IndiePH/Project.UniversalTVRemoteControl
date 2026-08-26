import 'dart:async';
import 'dart:developer';

import 'package:one_remote/remote_control/application/pin_required_exception.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_bravia_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

/// Logs calls for tests and offline development. Keeps the real PIN gate
/// alive (a fixed fake PIN) so the pairing UX can be exercised end-to-end
/// without a real Sony BRAVIA TV — mirrors [FakeHisenseTransportClient].
class FakeSonyBraviaTransportClient
    with TransportEventEmitterMixin
    implements SonyBraviaTransportClient {
  static const String _fakePin = '000000';

  final Set<String> _registered = <String>{};
  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      <String, StreamController<ConnectionState>>{};
  final Map<String, ConnectionState> _lastConnectionStates =
      <String, ConnectionState>{};

  @override
  Future<void> connect({required String deviceId}) async {
    if (!_registered.contains(deviceId)) {
      throw const PinRequiredException(
        'Sony BRAVIA TV requires PIN pairing (actRegister).',
      );
    }
    _emitConnectionState(deviceId, ConnectionState.connected);
    emitTransportEvent(
      TransportEvent(
        transport: 'sony_bravia',
        deviceId: deviceId,
        type: 'connected',
      ),
    );
  }

  @override
  Future<void> registerPin({required String deviceId, String? pin}) async {
    if (pin == null) {
      throw const PinRequiredException(
        'Sony BRAVIA TV requires PIN pairing (actRegister).',
      );
    }
    if (pin != _fakePin) {
      throw StateError('Incorrect pairing code. Please try again.');
    }
    _registered.add(deviceId);
    _emitConnectionState(deviceId, ConnectionState.connected);
    log(
      'Sony BRAVIA fake actRegister: $deviceId',
      name: 'sony_bravia_transport',
    );
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    emitTransportEvent(
      TransportEvent(
        transport: 'sony_bravia',
        deviceId: deviceId,
        type: 'key_sent',
        message: keyCode,
      ),
    );
    log(
      'Sony BRAVIA fake sendKey: $deviceId -> $keyCode',
      name: 'sony_bravia_transport',
    );
  }

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId}) async =>
      const TvDeviceInfo(modelIdentifier: 'sony_bravia_ip_control');

  @override
  Future<void> probe(String host) async {}

  @override
  Future<void> clearPairing({required String deviceId}) async {
    _registered.remove(deviceId);
    _emitConnectionState(deviceId, ConnectionState.disconnected);
  }

  @override
  Future<String?> resolveAppUri({
    required String deviceId,
    required String titleContains,
  }) async => null;

  @override
  Future<void> launchApp({
    required String deviceId,
    required String uri,
  }) async {
    emitTransportEvent(
      TransportEvent(
        transport: 'sony_bravia',
        deviceId: deviceId,
        type: 'app_launched',
        message: uri,
      ),
    );
    log(
      'Sony BRAVIA fake launchApp: $deviceId -> $uri',
      name: 'sony_bravia_transport',
    );
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _connectionControllerFor(deviceId).stream;

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
