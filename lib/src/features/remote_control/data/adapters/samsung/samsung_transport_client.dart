import 'package:one_remote/src/features/remote_control/data/adapters/transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/transport_event_source.dart';

abstract class SamsungTransportClient
    implements TransportClient, TransportEventSource {
  Future<void> connect({required String deviceId});

  /// Whether the TV has signaled an IME / text session (remote typing may work).
  Stream<bool> watchRemoteTextInputReady(String deviceId);

  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  });

  Future<void> sendKey({required String deviceId, required String keyCode});

  Future<void> sendText({required String deviceId, required String text});
}
