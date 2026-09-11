import 'package:one_remote/remote_control/data/adapters/transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_source.dart';
import 'package:one_remote/remote_control/domain/models/key_hold_phase.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract class RokuTransportClient
    implements TransportClient, TransportEventSource {
  Future<void> connect({required String deviceId});

  Future<void> sendKey({required String deviceId, required String keyCode});

  /// Sends one edge of a held key press via Roku's official ECP
  /// `/keydown/`/`/keyup/` endpoints — genuinely distinct from `/keypress/`,
  /// not a parameterization of it. A single `keydown` sustains the hold on
  /// the TV's own firmware; the client only controls release timing. See
  /// `references/goals/goal-long-press-key.md` fact #16-19.
  Future<void> sendKeyHold({
    required String deviceId,
    required String keyCode,
    required KeyHoldPhase phase,
  });

  Future<void> launchApp({required String deviceId, required String appId});

  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId});

  Future<void> probe(String host);

  Future<void> clearPairing({required String deviceId});
}
