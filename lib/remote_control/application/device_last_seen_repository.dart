/// Optional persistence for the last successful discovery observation of a
/// saved device.
///
/// Kept separate from [DeviceRepository] so in-memory and test repositories
/// that do not need orphan tracking remain source-compatible.
abstract interface class DeviceLastSeenRepository {
  Future<DateTime?> getLastSeenAt(String deviceId);

  Future<void> setLastSeenAt({
    required String deviceId,
    required DateTime timestamp,
  });
}
