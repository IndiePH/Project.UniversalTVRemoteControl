import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/tv_device_selection.dart';
import 'package:one_remote/remote_control/data/in_memory_device_repository.dart';
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

  group('TvDeviceSelection.tryPersistLastUsed', () {
    test('persists last used when policy allows switch', () async {
      final repository = InMemoryDeviceRepository();
      await repository.saveDevice(deviceA);
      await repository.saveDevice(deviceB);

      final persisted = await TvDeviceSelection.tryPersistLastUsed(
        device: deviceB,
        activeDeviceId: null,
        isPro: false,
        deviceRepository: repository,
      );

      expect(persisted, isTrue);
      expect((await repository.getLastUsedDevice())?.id, 'b');
    });

    test('returns false and does not persist when policy blocks switch', () async {
      final repository = InMemoryDeviceRepository();
      await repository.saveDevice(deviceA);
      await repository.saveDevice(deviceB);
      await repository.setLastUsedDevice('a');

      final persisted = await TvDeviceSelection.tryPersistLastUsed(
        device: deviceB,
        activeDeviceId: 'a',
        isPro: false,
        deviceRepository: repository,
      );

      expect(persisted, isFalse);
      expect((await repository.getLastUsedDevice())?.id, 'a');
    });
  });
}
