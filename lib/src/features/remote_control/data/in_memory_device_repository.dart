import 'package:universal_tv_remove_control/src/features/remote_control/application/device_repository.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/device_capability.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_device.dart';

/// In-memory repository used during early development and widget testing.
///
/// This keeps behavior deterministic while persistence/network layers are not
/// implemented yet.
class InMemoryDeviceRepository implements DeviceRepository {
  InMemoryDeviceRepository()
    : _devices = const [
        TvDevice(
          id: 'samsung-living-room',
          displayName: 'Living Room TV',
          brand: TvBrand.samsung,
          capabilities: {
            DeviceCapability.keyCommands,
            DeviceCapability.textInput,
            DeviceCapability.powerControl,
          },
        ),
      ];

  final List<TvDevice> _devices;
  final List<String> _recentManualIps = [];
  final Map<String, DateTime> _lastSuccessfulPairingByDeviceId = {
    'samsung-living-room': DateTime.now().subtract(const Duration(minutes: 5)),
  };
  String _lastUsedDeviceId = 'samsung-living-room';

  @override
  Future<List<TvDevice>> getSavedDevices() async => List.unmodifiable(_devices);

  @override
  Future<TvDevice?> getLastUsedDevice() async {
    for (final device in _devices) {
      if (device.id == _lastUsedDeviceId) {
        return device;
      }
    }
    return null;
  }

  @override
  Future<List<String>> getRecentManualIps() async =>
      List.unmodifiable(_recentManualIps);

  @override
  Future<DateTime?> getLastSuccessfulPairingAt(String deviceId) async =>
      _lastSuccessfulPairingByDeviceId[deviceId];

  @override
  Future<void> saveDevice(TvDevice device) async {
    final index = _devices.indexWhere((item) => item.id == device.id);
    if (index == -1) {
      _devices.add(device);
      return;
    }
    _devices[index] = device;
  }

  @override
  Future<void> removeSavedDevice(String deviceId) async {
    _devices.removeWhere((device) => device.id == deviceId);
    _lastSuccessfulPairingByDeviceId.remove(deviceId);

    // Keep last-used reference valid after deletion.
    final hasLastUsed = _devices.any((device) => device.id == _lastUsedDeviceId);
    if (hasLastUsed) {
      return;
    }
    _lastUsedDeviceId = _devices.isEmpty ? '' : _devices.first.id;
  }

  @override
  Future<void> saveRecentManualIp(String ipAddress) async {
    _recentManualIps.remove(ipAddress);
    _recentManualIps.insert(0, ipAddress);
    if (_recentManualIps.length > 5) {
      _recentManualIps.removeLast();
    }
  }

  @override
  Future<void> setLastSuccessfulPairingAt({
    required String deviceId,
    required DateTime timestamp,
  }) async {
    _lastSuccessfulPairingByDeviceId[deviceId] = timestamp;
  }

  @override
  Future<void> setLastUsedDevice(String deviceId) async {
    _lastUsedDeviceId = deviceId;
  }
}
