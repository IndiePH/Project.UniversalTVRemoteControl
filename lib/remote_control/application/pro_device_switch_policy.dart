import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Pro vs free-tier rules for switching the active paired TV.
final class ProDeviceSwitchPolicy {
  const ProDeviceSwitchPolicy._();

  /// Whether the user may select [device] as the active TV.
  ///
  /// Free users may pick any saved TV when none is active; otherwise only the
  /// current active TV (re-tap) is allowed until they upgrade.
  static bool canSwitchTo({
    required TvDevice device,
    required String? activeDeviceId,
    required bool isPro,
  }) {
    if (isPro) {
      return true;
    }
    if (activeDeviceId == null) {
      return true;
    }
    return activeDeviceId == device.id;
  }

  /// Whether a non-active saved-TV row should show the Pro lock affordance.
  static bool isSwitchLocked({
    required TvDevice device,
    required String? activeDeviceId,
    required bool isPro,
  }) {
    if (isPro || activeDeviceId == null) {
      return false;
    }
    return activeDeviceId != device.id;
  }

  /// Whether a device switcher or list may initiate a switch to another TV.
  static bool canSwitchBetweenSavedDevices({
    required bool isPro,
    required String? activeDeviceId,
  }) {
    return isPro || activeDeviceId == null;
  }
}
