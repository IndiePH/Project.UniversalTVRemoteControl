import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/saved_device_display_ordering.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  const deviceA = TvDevice(
    id: 'a',
    displayName: 'TV A',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands},
  );
  const deviceB = TvDevice(
    id: 'b',
    displayName: 'TV B',
    brand: TvBrand.lg,
    capabilities: {DeviceCapability.keyCommands},
  );
  const deviceC = TvDevice(
    id: 'c',
    displayName: 'TV C',
    brand: TvBrand.tcl,
    capabilities: {DeviceCapability.keyCommands},
  );

  group('SavedDeviceDisplayOrdering.activeFirst', () {
    test('returns empty list unchanged', () {
      expect(
        SavedDeviceDisplayOrdering.activeFirst(
          savedDevices: const [],
          activeDeviceId: 'a',
        ),
        isEmpty,
      );
    });

    test('returns original order when active is already first', () {
      const saved = [deviceA, deviceB, deviceC];
      expect(
        SavedDeviceDisplayOrdering.activeFirst(
          savedDevices: saved,
          activeDeviceId: 'a',
        ),
        saved,
      );
    });

    test('moves active device to the front', () {
      const saved = [deviceA, deviceB, deviceC];
      expect(
        SavedDeviceDisplayOrdering.activeFirst(
          savedDevices: saved,
          activeDeviceId: 'c',
        ),
        [deviceC, deviceA, deviceB],
      );
    });

    test('returns original order when activeDeviceId is null', () {
      const saved = [deviceA, deviceB];
      expect(
        SavedDeviceDisplayOrdering.activeFirst(
          savedDevices: saved,
          activeDeviceId: null,
        ),
        saved,
      );
    });
  });
}
