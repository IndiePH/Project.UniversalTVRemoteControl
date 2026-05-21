import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Removes saved TVs beyond the active device when free-tier policy applies.
final class FreeTierSavedDeviceCleanup {
  const FreeTierSavedDeviceCleanup._();

  static Future<bool> removeNonActiveSavedDevices({
    required bool isFreeTier,
    required String? activeDeviceId,
    required List<TvDevice> savedDevices,
    required RemoteCommandService commandService,
    required DeviceRepository deviceRepository,
  }) async {
    if (!isFreeTier || activeDeviceId == null) {
      return false;
    }
    final devicesToRemove = savedDevices
        .where((device) => device.id != activeDeviceId)
        .toList(growable: false);
    for (final device in devicesToRemove) {
      await commandService.unpairDevice(device: device);
      await deviceRepository.removeSavedDevice(device.id);
    }
    return devicesToRemove.isNotEmpty;
  }
}
