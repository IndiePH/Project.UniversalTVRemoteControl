import 'dart:async';
import 'dart:developer';

import 'package:one_remote/src/features/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/transport_event_emitter_mixin.dart';

/// Placeholder transport used until the real Samsung socket/auth client is wired.
class FakeSamsungTransportClient
    with TransportEventEmitterMixin
    implements SamsungTransportClient {
  final Set<String> _connectedDeviceIds = <String>{};
  final Map<String, StreamController<bool>> _imeReadyBroadcasters =
      <String, StreamController<bool>>{};

  void _notifyImeReady(String deviceId, bool value) {
    final c = _imeReadyBroadcasters[deviceId];
    if (c != null && !c.isClosed) {
      c.add(value);
    }
  }

  @override
  Future<void> connect({required String deviceId}) async {
    _connectedDeviceIds.add(deviceId);
    _notifyImeReady(deviceId, true);
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

  Future<void> _ensureConnected(String deviceId) async {
    if (_connectedDeviceIds.contains(deviceId)) {
      return;
    }
    await connect(deviceId: deviceId);
  }
}
