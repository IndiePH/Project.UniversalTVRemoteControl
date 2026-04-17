import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:universal_tv_remove_control/src/features/remote_control/data/adapters/samsung/samsung_transport_client.dart';

/// WebSocket transport scaffold for Samsung TVs.
///
/// Notes:
/// - This keeps protocol details isolated from UI/adapter routing.
/// - It currently assumes modern Samsung remote-control channel format.
/// - Device host lookup is delegated to [hostResolver] until repository models
///   carry explicit network endpoint metadata.
class RealSamsungTransportClient implements SamsungTransportClient {
  RealSamsungTransportClient({
    required String Function(String deviceId) hostResolver,
    this.clientName = 'RemoteOne',
  }) : _hostResolver = hostResolver;

  final String Function(String deviceId) _hostResolver;
  final String clientName;
  final Map<String, WebSocket> _socketsByDeviceId = <String, WebSocket>{};

  @override
  Future<void> connect({
    required String deviceId,
  }) async {
    final existing = _socketsByDeviceId[deviceId];
    if (existing != null && existing.readyState == WebSocket.open) {
      return;
    }

    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Samsung host resolver returned an empty host.');
    }

    final encodedName = base64Encode(utf8.encode(clientName));
    final uri = Uri.parse(
      'ws://$host:8001/api/v2/channels/samsung.remote.control?name=$encodedName',
    );
    final socket = await WebSocket.connect(uri.toString());
    _socketsByDeviceId[deviceId] = socket;
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    final socket = await _socketFor(deviceId);
    final payload = <String, dynamic>{
      'method': 'ms.remote.control',
      'params': <String, dynamic>{
        'Cmd': 'Click',
        'DataOfCmd': keyCode,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    };
    socket.add(jsonEncode(payload));
  }

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {
    final socket = await _socketFor(deviceId);

    // Placeholder message shape for text input path; may vary by model/firmware.
    final payload = <String, dynamic>{
      'method': 'ms.remote.control',
      'params': <String, dynamic>{
        'Cmd': text,
        'DataOfCmd': 'base64',
        'Option': 'false',
        'TypeOfRemote': 'SendInputString',
      },
    };
    socket.add(jsonEncode(payload));
  }

  Future<WebSocket> _socketFor(String deviceId) async {
    await connect(deviceId: deviceId);
    final socket = _socketsByDeviceId[deviceId];
    if (socket == null || socket.readyState != WebSocket.open) {
      throw StateError('Samsung socket is not connected for device: $deviceId');
    }
    return socket;
  }
}
