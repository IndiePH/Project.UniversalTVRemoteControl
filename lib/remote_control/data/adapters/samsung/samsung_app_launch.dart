/// Samsung Tizen app launch routing via WebSocket `ed.apps.launch`.
///
/// [SamsungWebSocketTransportClient] intercepts [samsungLaunchPrefix] key codes
/// and emits `ms.channel.emit` instead of `SendRemoteKey`.
const String samsungLaunchPrefix = 'LAUNCH:';

/// Well-known Tizen app IDs for common streaming / browser shortcuts.
///
/// IDs can vary by model/region; these match widely documented Samsung TV values.
abstract final class SamsungTizenAppIds {
  static const browser = 'org.tizen.browser';
  static const netflix = '3201907018807';
  static const primeVideo = '3201910019365';
  static const youtube = '111299001912';
  static const disneyPlus = '3201901017640';
}

String samsungLaunchKeyFor(String appId) => '$samsungLaunchPrefix$appId';
