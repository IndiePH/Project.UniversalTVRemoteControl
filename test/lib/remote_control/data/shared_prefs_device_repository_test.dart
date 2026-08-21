import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/shared_prefs_device_repository.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

TvDevice _device({
  required String id,
  required String displayName,
  required TvBrand brand,
  String? host,
}) => TvDevice(
  id: id,
  displayName: displayName,
  brand: brand,
  capabilities: const <DeviceCapability>{},
  host: host,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsDeviceRepository identity indexing', () {
    test(
      'getSavedDevices registers host->stableId for each saved device',
      () async {
        final registry = DeviceIdentityRegistry();
        final repo = SharedPrefsDeviceRepository(identityRegistry: registry);
        await repo.saveDevice(
          _device(
            id: 'samsung-udn-1',
            displayName: 'Living Room',
            brand: TvBrand.samsung,
            host: '192.168.1.10',
          ),
        );
        await repo.saveDevice(
          _device(
            id: 'roku-serial-2',
            displayName: 'Bedroom',
            brand: TvBrand.roku,
            host: '192.168.1.20',
          ),
        );

        await repo.getSavedDevices();

        expect(registry.stableIdForHost('192.168.1.10'), 'samsung-udn-1');
        expect(registry.stableIdForHost('192.168.1.20'), 'roku-serial-2');
      },
    );

    test('getLastUsedDevice registers its host->stableId', () async {
      final registry = DeviceIdentityRegistry();
      final repo = SharedPrefsDeviceRepository(identityRegistry: registry);
      final device = _device(
        id: 'lg-udn-3',
        displayName: 'Kitchen',
        brand: TvBrand.lg,
        host: '192.168.1.30',
      );
      await repo.saveDevice(device);
      await repo.setLastUsedDevice(device.id);

      await repo.getLastUsedDevice();

      expect(registry.stableIdForHost('192.168.1.30'), 'lg-udn-3');
    });

    test('saveDevice registers the mapping immediately', () async {
      final registry = DeviceIdentityRegistry();
      final repo = SharedPrefsDeviceRepository(identityRegistry: registry);

      await repo.saveDevice(
        _device(
          id: 'hisense-udn-4',
          displayName: 'Office',
          brand: TvBrand.hisense,
          host: '192.168.1.40',
        ),
      );

      expect(registry.stableIdForHost('192.168.1.40'), 'hisense-udn-4');
    });

    test('legacy devices without stableId are not indexed', () async {
      final registry = DeviceIdentityRegistry();
      final repo = SharedPrefsDeviceRepository(identityRegistry: registry);
      await repo.saveDevice(
        _device(
          id: '192.168.1.50',
          displayName: 'Legacy',
          brand: TvBrand.samsung,
          host: '192.168.1.50',
        ),
      );

      await repo.getSavedDevices();

      expect(registry.stableIdForHost('192.168.1.50'), isNull);
    });

    test('no registry wired is a no-op (does not throw)', () async {
      final repo = SharedPrefsDeviceRepository();
      await repo.saveDevice(
        _device(
          id: 'samsung-udn-6',
          displayName: 'Patio',
          brand: TvBrand.samsung,
          host: '192.168.1.60',
        ),
      );

      await repo.getSavedDevices();
      // No assertions; completing without throwing is the contract.
    });
  });

  group('SharedPrefsDeviceRepository identity migration', () {
    test('moves device and metadata from legacy id to stable id', () async {
      final registry = DeviceIdentityRegistry();
      final repo = SharedPrefsDeviceRepository(identityRegistry: registry);
      final legacy = _device(
        id: 'samsung-192.168.1.10',
        displayName: 'Living Room',
        brand: TvBrand.samsung,
        host: '192.168.1.10',
      );
      final migrated = legacy.copyWith(
        id: 'samsung-udn-1',
        host: '192.168.1.10',
      );
      final pairedAt = DateTime(2026, 8, 21, 15, 30);

      await repo.saveDevice(legacy);
      await repo.setLastUsedDevice(legacy.id);
      await repo.setLastSuccessfulPairingAt(
        deviceId: legacy.id,
        timestamp: pairedAt,
      );
      await repo.saveDeviceSystemInfo(legacy.id, {'model': 'QN90A'});

      final didMigrate = await repo.migrateDeviceIdentity(
        legacyId: legacy.id,
        device: migrated,
      );

      expect(didMigrate, isTrue);
      final saved = await repo.getSavedDevices();
      expect(saved, hasLength(1));
      expect(saved.single.id, 'samsung-udn-1');
      expect(saved.single.host, '192.168.1.10');
      final lastUsed = await repo.getLastUsedDevice();
      expect(lastUsed?.id, 'samsung-udn-1');
      expect(lastUsed?.host, '192.168.1.10');
      expect(await repo.getLastSuccessfulPairingAt('samsung-udn-1'), pairedAt);
      expect(await repo.getDeviceSystemInfo('samsung-udn-1'), {
        'model': 'QN90A',
      });
      expect(await repo.getLastSuccessfulPairingAt(legacy.id), isNull);
      expect(await repo.getDeviceSystemInfo(legacy.id), isNull);
      expect(registry.stableIdForHost('192.168.1.10'), 'samsung-udn-1');
    });

    test('is safe to retry after the first migration completes', () async {
      final repo = SharedPrefsDeviceRepository();
      final legacy = _device(
        id: 'lg-192.168.1.20',
        displayName: 'Bedroom',
        brand: TvBrand.lg,
        host: '192.168.1.20',
      );
      final migrated = legacy.copyWith(id: 'lg-udn-2');
      await repo.saveDevice(legacy);

      expect(
        await repo.migrateDeviceIdentity(legacyId: legacy.id, device: migrated),
        isTrue,
      );
      expect(
        await repo.migrateDeviceIdentity(legacyId: legacy.id, device: migrated),
        isFalse,
      );
      expect((await repo.getSavedDevices()).map((device) => device.id), [
        'lg-udn-2',
      ]);
    });

    test('does not migrate when the replacement id is not stable', () async {
      final repo = SharedPrefsDeviceRepository();
      final legacy = _device(
        id: 'roku-192.168.1.30',
        displayName: 'Office',
        brand: TvBrand.roku,
        host: '192.168.1.30',
      );
      await repo.saveDevice(legacy);

      final didMigrate = await repo.migrateDeviceIdentity(
        legacyId: legacy.id,
        device: legacy.copyWith(id: 'roku-192.168.1.31'),
      );

      expect(didMigrate, isFalse);
      expect((await repo.getSavedDevices()).single.id, legacy.id);
    });
  });
}
