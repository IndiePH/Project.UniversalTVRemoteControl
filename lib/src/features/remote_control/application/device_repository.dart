import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

abstract class DeviceRepository {
  Future<List<TvDevice>> getSavedDevices();
  Future<TvDevice?> getLastUsedDevice();
  Future<List<String>> getRecentManualIps();
  Future<DateTime?> getLastSuccessfulPairingAt(String deviceId);
  Future<void> saveDevice(TvDevice device);
  Future<void> removeSavedDevice(String deviceId);
  Future<void> saveRecentManualIp(String ipAddress);
  Future<void> setLastSuccessfulPairingAt({
    required String deviceId,
    required DateTime timestamp,
  });
  Future<void> setLastUsedDevice(String deviceId);
  Future<void> saveDeviceSystemInfo(String deviceId, Map<String, dynamic> info);
  Future<Map<String, dynamic>?> getDeviceSystemInfo(String deviceId);
}
