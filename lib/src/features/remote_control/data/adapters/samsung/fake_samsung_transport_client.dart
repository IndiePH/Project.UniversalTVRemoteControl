import 'dart:developer';

import 'package:one_remote/src/features/remote_control/data/adapters/samsung/samsung_transport_client.dart';

/// Placeholder transport used until the real Samsung socket/auth client is wired.
class FakeSamsungTransportClient implements SamsungTransportClient {
  final Set<String> _connectedDeviceIds = <String>{};

  @override
  Future<void> connect({
    required String deviceId,
  }) async {
    _connectedDeviceIds.add(deviceId);
    log('Samsung transport connected: $deviceId', name: 'samsung_transport');
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    await _ensureConnected(deviceId);
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
    log(
      'Samsung transport sendText: $deviceId -> "$text"',
      name: 'samsung_transport',
    );
  }

  Future<void> _ensureConnected(String deviceId) async {
    if (_connectedDeviceIds.contains(deviceId)) {
      return;
    }
    await connect(deviceId: deviceId);
  }
}
