/// Tracks whether per-device diagnostic info has already been logged.
///
/// Transport clients can use this to avoid repeating static device/session
/// metadata logs on every message while still allowing reset on reconnect.
final class AdapterDeviceInfoLogGate {
  final Set<String> _loggedByDeviceId = <String>{};

  bool shouldLog(String deviceId) => _loggedByDeviceId.add(deviceId);

  void reset(String deviceId) {
    _loggedByDeviceId.remove(deviceId);
  }
}
