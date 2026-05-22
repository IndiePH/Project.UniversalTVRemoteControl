import 'package:one_remote/remote_control/data/adapters/transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_source.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract class SamsungTransportClient
    implements TransportClient, TransportEventSource {
  Future<void> connect({required String deviceId});

  /// Whether the TV has signaled an IME / text session (remote typing may work).
  Stream<bool> watchRemoteTextInputReady(String deviceId);

  /// Sends a lightweight IME probe command and returns whether input is ready.
  Future<bool> probeRemoteTextInputReady({
    required String deviceId,
    Duration timeout = const Duration(milliseconds: 750),
  });

  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  });

  Future<void> sendKey({required String deviceId, required String keyCode});

  Future<void> sendText({required String deviceId, required String text});

  /// Lightweight TCP reachability check. Tries Samsung ports in order.
  /// Completes if the TV is reachable; throws otherwise.
  Future<void> probe(String host);

  /// Cancels an in-progress pairing approval wait. Safe to call when no
  /// pairing is active.
  void cancelPairing(String deviceId);

  /// Clears in-memory pairing token, cached device info, and open sockets for
  /// [deviceId] so the next pair attempt re-enters TV approval.
  Future<void> clearPairing({required String deviceId});

  /// Last `ms.channel.connect` details for [deviceId], if the TV sent them.
  TvDeviceInfo? getCachedDeviceInfo(String deviceId);
}
