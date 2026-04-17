import 'dart:async';

import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

class FakeDeviceDiscoveryService implements DeviceDiscoveryService {
  static const List<TvDevice> _devices = [
    TvDevice(
      id: 'samsung-living-room',
      displayName: 'Samsung QLED - Living Room',
      brand: TvBrand.samsung,
      capabilities: {
        DeviceCapability.keyCommands,
        DeviceCapability.textInput,
        DeviceCapability.powerControl,
      },
    ),
    TvDevice(
      id: 'lg-bedroom',
      displayName: 'LG OLED - Bedroom',
      brand: TvBrand.lg,
      capabilities: {
        DeviceCapability.keyCommands,
        DeviceCapability.powerControl,
      },
    ),
    TvDevice(
      id: 'hisense-office',
      displayName: 'Hisense U7 - Office',
      brand: TvBrand.hisense,
      capabilities: {
        DeviceCapability.keyCommands,
        DeviceCapability.powerControl,
      },
    ),
  ];

  @override
  Future<List<TvDevice>> discoverDevices() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return _devices;
  }
}
