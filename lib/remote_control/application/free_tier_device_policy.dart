import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/free_tier_saved_device_cleanup.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Result of applying free-tier saved-device cleanup.
final class FreeTierSavedDeviceCleanupOutcome {
  const FreeTierSavedDeviceCleanupOutcome({
    required this.removed,
    required this.savedDevices,
  });

  final bool removed;
  final List<TvDevice> savedDevices;
}

/// Free-tier device limits: entitlement resolution, cleanup, and replace-before-pair.
final class FreeTierDevicePolicy {
  const FreeTierDevicePolicy._();

  /// Free tier is resolved only when entitlement is explicitly [notEntitled].
  static bool isFreeTier(ProEntitlementStatus status) {
    return status == ProEntitlementStatus.notEntitled;
  }

  /// Resolves free tier from the current entitlement service snapshot.
  static bool isFreeTierFrom(ProEntitlementService entitlementService) {
    return isFreeTier(entitlementService.statusNotifier.value);
  }

  /// Resolves free tier from a Pro gate ([isPro] is false for unknown and free).
  static bool isFreeTierWhenNotPro(bool isPro) {
    return !isPro;
  }

  /// Removes extra saved TVs and reloads the list when cleanup ran.
  static Future<FreeTierSavedDeviceCleanupOutcome> cleanupExtraSavedDevices({
    required bool isFreeTier,
    required String? activeDeviceId,
    required List<TvDevice> savedDevices,
    required RemoteCommandService commandService,
    required DeviceRepository deviceRepository,
  }) async {
    final removed = await FreeTierSavedDeviceCleanup.removeNonActiveSavedDevices(
      isFreeTier: isFreeTier,
      activeDeviceId: activeDeviceId,
      savedDevices: savedDevices,
      commandService: commandService,
      deviceRepository: deviceRepository,
    );
    if (!removed) {
      return FreeTierSavedDeviceCleanupOutcome(
        removed: false,
        savedDevices: savedDevices,
      );
    }
    final updated = await deviceRepository.getSavedDevices();
    return FreeTierSavedDeviceCleanupOutcome(
      removed: true,
      savedDevices: updated,
    );
  }

  /// Unpairs and removes the active TV before pairing a new one when not Pro.
  ///
  /// Uses the same `!isPro` gate as device-switch policy (includes unknown).
  static Future<bool> replaceActiveDeviceBeforePairingWhenNotPro({
    required bool isPro,
    required String? activeDeviceId,
    required TvDevice newDevice,
    required List<TvDevice> savedDevices,
    required RemoteCommandService commandService,
    required DeviceRepository deviceRepository,
  }) {
    return replaceActiveDeviceBeforePairing(
      isFreeTier: !isPro,
      activeDeviceId: activeDeviceId,
      newDevice: newDevice,
      savedDevices: savedDevices,
      commandService: commandService,
      deviceRepository: deviceRepository,
    );
  }

  /// Unpairs and removes the active TV before pairing a new one on free tier.
  ///
  /// Returns whether the active device was replaced.
  static Future<bool> replaceActiveDeviceBeforePairing({
    required bool isFreeTier,
    required String? activeDeviceId,
    required TvDevice newDevice,
    required List<TvDevice> savedDevices,
    required RemoteCommandService commandService,
    required DeviceRepository deviceRepository,
  }) async {
    if (!isFreeTier || activeDeviceId == null || activeDeviceId == newDevice.id) {
      return false;
    }
    TvDevice? activeDevice;
    for (final saved in savedDevices) {
      if (saved.id == activeDeviceId) {
        activeDevice = saved;
        break;
      }
    }
    if (activeDevice == null) {
      return false;
    }
    await commandService.unpairDevice(device: activeDevice);
    await deviceRepository.removeSavedDevice(activeDevice.id);
    return true;
  }
}
