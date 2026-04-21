import 'package:one_remote/src/features/remote_control/data/adapters/transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/transport_event_source.dart';

enum LgRegistrationState { connecting, registered, failed }

abstract class LgTransportClient implements TransportClient, TransportEventSource {
  Future<void> connect({required String deviceId});

  /// First-time pairing only. Triggers the TV on-screen prompt and waits for approval.
  /// Resolves with the client-key issued by the TV.
  /// Throws [LgPairingTimeoutException] if [timeout] elapses without a response.
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  });

  Future<void> sendKey({required String deviceId, required String keyCode});

  Future<void> sendText({required String deviceId, required String text});

  Stream<LgRegistrationState> watchRegistrationState(String deviceId);

  /// Emits whether the TV currently has an active text-input field focused.
  /// webOS SSAP exposes no IME-focus subscription; implementations emit
  /// constant [false] until a subscription API is confirmed on hardware.
  Stream<bool> watchRemoteTextInputReady(String deviceId);

  Future<void> disconnect({required String deviceId});
}
