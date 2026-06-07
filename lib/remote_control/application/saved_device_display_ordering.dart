import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Shared ordering for saved-TV lists (active device first).
final class SavedDeviceDisplayOrdering {
  const SavedDeviceDisplayOrdering._();

  static List<TvDevice> activeFirst({
    required List<TvDevice> savedDevices,
    required String? activeDeviceId,
  }) {
    if (savedDevices.isEmpty || activeDeviceId == null) {
      return savedDevices;
    }
    final activeIndex = savedDevices.indexWhere(
      (device) => device.id == activeDeviceId,
    );
    if (activeIndex <= 0) {
      return savedDevices;
    }
    return [
      savedDevices[activeIndex],
      ...savedDevices.take(activeIndex),
      ...savedDevices.skip(activeIndex + 1),
    ];
  }
}
