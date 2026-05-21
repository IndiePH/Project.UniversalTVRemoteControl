import 'package:one_remote/remote_control/data/adapters/transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_source.dart';

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

  /// Lightweight TCP reachability check. Tries LG ports in order.
  /// Completes if the TV is reachable; throws otherwise.
  Future<void> probe(String host);

  /// Disconnects, clears the stored client-key, and resets all in-memory
  /// pairing state for [deviceId]. Call when the user explicitly removes the device.
  Future<void> clearPairing({required String deviceId});

  /// Cancels an in-progress pairing attempt without clearing the stored
  /// client-key. Safe to call when no pairing is active.
  void cancelPairing(String deviceId);

  /// Queries the TV for model name, software version, and other device metadata.
  /// Returns null if the TV does not respond or the request fails.
  Future<Map<String, dynamic>?> querySystemInfo({required String deviceId});
}
