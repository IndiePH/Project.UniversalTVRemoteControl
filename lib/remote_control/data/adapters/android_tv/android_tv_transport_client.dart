import 'package:one_remote/remote_control/data/adapters/transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_source.dart';
import 'package:one_remote/remote_control/domain/models/key_hold_phase.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract class AndroidTvTransportClient
    implements TransportClient, TransportEventSource {
  Future<void> connect({required String deviceId});

  /// [code] is a 6-character hex string (e.g. `"F3A2C1"`), not a 4-digit decimal PIN.
  Future<void> submitPairingCode({
    required String deviceId,
    required String code,
  });

  Future<void> sendKey({required String deviceId, required String keyCode});

  /// Sends one edge of a held key press using the protocol's native
  /// `START_LONG`/`END_LONG` `RemoteDirection` — see
  /// `references/guide-tv-remote-protocols.md`'s "Key codes" section.
  /// [keyCode] is the string-encoded integer from [AndroidTvKeyMapper].
  Future<void> sendKeyHold({
    required String deviceId,
    required String keyCode,
    required KeyHoldPhase phase,
  });

  Future<void> sendText({required String deviceId, required String text});

  Future<void> sendAppLink({required String deviceId, required String appLink});

  /// Lightweight TCP reachability check. Completes if reachable; throws otherwise.
  Future<void> probe(String host);

  /// Disconnects, clears stored server certificate, and resets pairing state.
  Future<void> clearPairing({required String deviceId});

  /// Cancels an in-progress pairing handshake without clearing the stored
  /// certificate. Safe to call when no pairing is active.
  void cancelPairing(String deviceId);

  Future<TvDeviceInfo> queryDeviceInfo({required String deviceId});
}
