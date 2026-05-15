import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:one_remote/remote_control/data/adapters/tcl/roku_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class RokuHttpTransportClient
    with TransportEventEmitterMixin
    implements RokuTransportClient {
  RokuHttpTransportClient({
    String Function(String deviceId)? hostResolver,
    Duration requestTimeout = const Duration(seconds: 4),
  }) : _hostResolver = hostResolver ?? _defaultHostResolver,
       _requestTimeout = requestTimeout;

  final String Function(String deviceId) _hostResolver;
  final Duration _requestTimeout;
  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      <String, StreamController<ConnectionState>>{};
  final Map<String, ConnectionState> _lastConnectionStates =
      <String, ConnectionState>{};

  static final RegExp _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');

  @override
  Future<void> connect({required String deviceId}) async {
    _emitConnectionState(deviceId, ConnectionState.connecting);
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      _emitConnectionState(deviceId, ConnectionState.error);
      throw StateError('Roku host missing for deviceId: $deviceId');
    }
    await probe(host);
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
    await _post(deviceId: deviceId, path: '/keypress/$keyCode');
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
    await _post(deviceId: deviceId, path: '/launch/$appId');
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
    final body = await _get(deviceId: deviceId, path: '/query/device-info');
    final model = _extractXmlAttribute(body, 'model-name');
    final serial = _extractXmlAttribute(body, 'serial-number');
    final firmware = _extractXmlAttribute(body, 'software-version');
    return TvDeviceInfo(
      modelIdentifier: ['roku', model, serial].whereType<String>().join(':'),
      firmwareVersion: firmware,
    );
  }

  @override
  Future<void> probe(String host) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse('http://$host:8060/query/device-info'))
          .timeout(_requestTimeout);
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Roku probe failed (${response.statusCode})');
      }
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> clearPairing({required String deviceId}) async {
    _emitConnectionState(deviceId, ConnectionState.disconnected);
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _controllerFor(deviceId).stream;

  Future<void> _post({required String deviceId, required String path}) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Roku host missing for deviceId: $deviceId');
    }
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse('http://$host:8060$path'))
          .timeout(_requestTimeout);
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Roku request failed (${response.statusCode})');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _get({required String deviceId, required String path}) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Roku host missing for deviceId: $deviceId');
    }
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse('http://$host:8060$path'))
          .timeout(_requestTimeout);
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Roku request failed (${response.statusCode})');
      }
      return utf8.decode(await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b)));
    } finally {
      client.close(force: true);
    }
  }

  String? _extractXmlAttribute(String body, String key) {
    final regex = RegExp('<$key>([^<]+)</$key>', caseSensitive: false);
    final match = regex.firstMatch(body);
    return match?.group(1)?.trim();
  }

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
