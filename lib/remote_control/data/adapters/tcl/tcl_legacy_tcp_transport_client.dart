import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:one_remote/remote_control/data/adapters/tcl/tcl_legacy_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class TclLegacyTcpTransportClient
    with TransportEventEmitterMixin
    implements TclLegacyTransportClient {
  TclLegacyTcpTransportClient({
    String Function(String deviceId)? hostResolver,
    this.port = 4123,
    this._timeout = const Duration(seconds: 4),
  }) : _hostResolver = hostResolver ?? _defaultHostResolver;

  final String Function(String deviceId) _hostResolver;
  final int port;
  final Duration _timeout;
  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      <String, StreamController<ConnectionState>>{};
  final Map<String, ConnectionState> _lastConnectionStates =
      <String, ConnectionState>{};

  static final RegExp _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');

  @override
  Future<void> connect({required String deviceId}) async {
    _emitConnectionState(deviceId, ConnectionState.connecting);
    final host = _hostResolver(deviceId);
    if (host.isEmpty) {
      _emitConnectionState(deviceId, ConnectionState.error);
      throw StateError('Legacy TCL host missing for deviceId: $deviceId');
    }
    await probe(host);
    _emitConnectionState(deviceId, ConnectionState.connected);
    emitTransportEvent(
      TransportEvent(
        transport: 'tcl_legacy_wifi',
        deviceId: deviceId,
        type: 'connected',
      ),
    );
  }

  @override
  Future<void> sendFrame({
    required String deviceId,
    required String frame,
  }) async {
    final host = _hostResolver(deviceId);
    if (host.isEmpty) {
      throw StateError('Legacy TCL host missing for deviceId: $deviceId');
    }
    final socket = await Socket.connect(host, port, timeout: _timeout);
    try {
      socket.add(utf8.encode('$frame\r\n'));
      await socket.flush();
      await socket.close();
    } finally {
      socket.destroy();
    }
    emitTransportEvent(
      TransportEvent(
        transport: 'tcl_legacy_wifi',
        deviceId: deviceId,
        type: 'frame_sent',
        message: frame,
      ),
    );
  }

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId}) async =>
      const TvDeviceInfo(
        modelIdentifier: TclProtocolVariants.legacyWifiModelMarker,
      );

  @override
  Future<void> probe(String host) async {
    final socket = await Socket.connect(host, port, timeout: _timeout);
    await socket.close();
    socket.destroy();
  }

  @override
  Future<void> clearPairing({required String deviceId}) async {
    _emitConnectionState(deviceId, ConnectionState.disconnected);
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _controllerFor(deviceId).stream;

  StreamController<ConnectionState> _controllerFor(String deviceId) {
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
    final controller = _connectionControllers[deviceId];
    if (controller != null && !controller.isClosed) {
      controller.add(state);
    }
  }

  static String _defaultHostResolver(String deviceId) {
    final match = _ipv4.firstMatch(deviceId);
    return match?.group(1) ?? '';
  }
}
