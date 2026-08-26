import 'package:one_remote/remote_control/data/adapters/transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_source.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

/// Transport for Sony's BRAVIA IP Control protocol (REST/JSON-RPC over HTTP),
/// PIN-mode auth only — see guide-tv-remote-protocols.md's "Sony BRAVIA IP
/// Control" section for the wire-level details this implements.
abstract class SonyBraviaTransportClient
    implements TransportClient, TransportEventSource {
  /// Marks [deviceId] connected if a session already exists; throws
  /// `PinRequiredException` otherwise (mirrors Hisense's dynamic PIN gate —
  /// see `HisenseMqttTransportClient.connect`). Does not itself trigger the
  /// TV to display a PIN — see [registerPin].
  Future<void> connect({required String deviceId});

  /// Sends a named IRCC remote-key command (e.g. `'Up'`, `'VolumeUp'`).
  /// Resolved against this device's own `getRemoteControllerInfo` response —
  /// no code is ever hardcoded in the app, since Sony assigns them per
  /// model/firmware.
  Future<void> sendKey({required String deviceId, required String keyCode});

  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId});

  /// Bare, unauthenticated reachability probe — no pairing/session side
  /// effects, safe to call speculatively (relied on by `ManualAddVariantProbe`).
  Future<void> probe(String host);

  /// Calls Sony's `actRegister`. With [pin] `null`, this is the *first* call
  /// of the two-step handshake — it's expected to fail (401), and that
  /// failure is what makes the TV display an on-screen PIN. Called again
  /// with the PIN the user read off-screen, it completes registration and
  /// persists the resulting session (Basic-Auth header + cookie — both
  /// required on every later request) for [deviceId].
  Future<void> registerPin({required String deviceId, String? pin});

  Future<void> clearPairing({required String deviceId});

  /// Fetches this device's own installed-app list (`getApplicationList`,
  /// cached per host) and returns the launch `uri` of the first app whose
  /// title contains [titleContains] (case-insensitive), or `null` if none
  /// match. Kept host-scoped (not adapter-instance-scoped) since two paired
  /// Bravia TVs can have different apps installed under different URIs —
  /// see `guide-tv-remote-protocols.md`'s "Sony BRAVIA IP Control" section.
  Future<String?> resolveAppUri({
    required String deviceId,
    required String titleContains,
  });

  /// Launches the app at [uri] (as returned by [resolveAppUri]) via `setActiveApp`.
  Future<void> launchApp({required String deviceId, required String uri});
}
