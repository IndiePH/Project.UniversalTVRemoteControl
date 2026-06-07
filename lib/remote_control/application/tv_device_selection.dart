import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/pro_device_switch_policy.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Persists the user's active TV choice with Pro switch policy applied.
final class TvDeviceSelection {
  const TvDeviceSelection._();

  /// Returns false when Pro policy blocks switching to [device].
  static Future<bool> tryPersistLastUsed({
    required TvDevice device,
    required String? activeDeviceId,
    required bool isPro,
    required DeviceRepository deviceRepository,
  }) async {
    if (!ProDeviceSwitchPolicy.canSwitchTo(
      device: device,
      activeDeviceId: activeDeviceId,
      isPro: isPro,
    )) {
      return false;
    }
    await deviceRepository.setLastUsedDevice(device.id);
    return true;
  }
}
