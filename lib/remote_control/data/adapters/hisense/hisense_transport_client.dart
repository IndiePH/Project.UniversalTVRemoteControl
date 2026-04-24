import 'package:one_remote/remote_control/data/adapters/transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_source.dart';

/// Local-network VIDAA-style MQTT control (Hisense TVs, port 36669).
///
/// Topic layout follows community-documented patterns; the [mqttClientId]
/// segment must stay consistent across pairing and key sends for a session.
abstract class HisenseTransportClient
    implements TransportClient, TransportEventSource {
  /// Ensures an MQTT session to the TV for [deviceId] (host derived by caller).
  Future<void> connect({required String deviceId});

  /// Sends the 4-digit PIN shown on the TV after [connect], when the firmware
  /// requires first-time client registration.
  Future<void> submitAuthenticationCode({
    required String deviceId,
    required String fourDigitPin,
  });

  /// Publishes a remote key name (e.g. `KEY_UP`) to the TV MQTT `sendkey` topic.
  Future<void> sendKey({
    required String deviceId,
    required String keyName,
  });

  /// Launches a store/streaming app via VIDAA `launchapp` MQTT action.
  Future<void> launchVidaaApp({
    required String deviceId,
    required String displayName,
    required String url,
    int urlType = 37,
    int storeType = 0,
  });
}
