import 'dart:async';
import 'dart:developer';

import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';

/// Placeholder transport used until the real Samsung socket/auth client is wired.
class FakeSamsungTransportClient
    with TransportEventEmitterMixin
    implements SamsungTransportClient {
  final Set<String> _connectedDeviceIds = <String>{};
  final Map<String, StreamController<bool>> _imeReadyBroadcasters =
      <String, StreamController<bool>>{};
  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      <String, StreamController<ConnectionState>>{};
  final Map<String, ConnectionState> _lastConnectionStates =
      <String, ConnectionState>{};
  final Map<String, TvDeviceInfo> _cachedDeviceInfoByDeviceId =
      <String, TvDeviceInfo>{};

  void _notifyImeReady(String deviceId, bool value) {
    final c = _imeReadyBroadcasters[deviceId];
    if (c != null && !c.isClosed) {
      c.add(value);
    }
  }

  @override
  TvDeviceInfo? getCachedDeviceInfo(String deviceId) =>
      _cachedDeviceInfoByDeviceId[deviceId];

  @override
  Future<void> connect({required String deviceId}) async {
    _emitConnectionState(deviceId, ConnectionState.connecting);
    _connectedDeviceIds.add(deviceId);
    _cachedDeviceInfoByDeviceId[deviceId] = const TvDeviceInfo(
      modelIdentifier: 'FAKE-SAMSUNG',
      firmwareVersion: '0.0.0-fake',
      debugDetails: 'OS: FakeTizen\nFrame: fake-ms.channel.connect',
    );
    _notifyImeReady(deviceId, true);
    _emitConnectionState(deviceId, ConnectionState.connected);
    emitTransportEvent(
      TransportEvent(
        transport: 'samsung',
        deviceId: deviceId,
        type: 'connected',
      ),
    );
    log('Samsung transport connected: $deviceId', name: 'samsung_transport');
  }

  @override
  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  }) async {
    await _ensureConnected(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'samsung',
        deviceId: deviceId,
        type: 'pairing_approval_requested',
      ),
    );
    log(
      'Samsung transport requestPairingApproval: $deviceId via $triggerKeyCode',
      name: 'samsung_transport',
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
        transport: 'samsung',
        deviceId: deviceId,
        type: 'key_sent',
        message: keyCode,
      ),
    );
    log(
      'Samsung transport sendKey: $deviceId -> $keyCode',
      name: 'samsung_transport',
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
        transport: 'samsung',
        deviceId: deviceId,
        type: 'text_sent',
      ),
    );
    log(
      'Samsung transport sendText: $deviceId -> "$text"',
      name: 'samsung_transport',
    );
  }

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) {
    return Stream<bool>.multi((controller) {
      controller.add(_connectedDeviceIds.contains(deviceId));
      final broadcaster = _imeReadyBroadcasters.putIfAbsent(
        deviceId,
        () => StreamController<bool>.broadcast(),
      );
      late final StreamSubscription<bool> sub;
      sub = broadcaster.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = () {
        sub.cancel();
      };
    });
  }

  @override
  Future<bool> probeRemoteTextInputReady({
    required String deviceId,
    Duration timeout = const Duration(milliseconds: 750),
  }) async {
    await _ensureConnected(deviceId);
    return _connectedDeviceIds.contains(deviceId);
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) {
    return _connectionControllerFor(deviceId).stream;
  }

  @override
  Future<void> probe(String host) async {}

  @override
  void cancelPairing(String deviceId) {}

  @override
  Future<void> clearPairing({required String deviceId}) async {
    _connectedDeviceIds.remove(deviceId);
    _cachedDeviceInfoByDeviceId.remove(deviceId);
    _imeReadyBroadcasters.remove(deviceId)?.close();
    _emitConnectionState(deviceId, ConnectionState.disconnected);
    log('Samsung transport clearPairing: $deviceId', name: 'samsung_transport');
  }

  Future<void> _ensureConnected(String deviceId) async {
    if (_connectedDeviceIds.contains(deviceId)) {
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
