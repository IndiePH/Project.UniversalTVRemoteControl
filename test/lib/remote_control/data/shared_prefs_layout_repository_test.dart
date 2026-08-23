import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/shared_prefs_layout_repository.dart';
import 'package:one_remote/remote_control/domain/models/layout_position.dart';
import 'package:one_remote/remote_control/domain/models/layout_zone.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsLayoutRepository', () {
    test('returns empty map when no layout saved', () async {
      final repo = SharedPrefsLayoutRepository();
      final loaded = await repo.loadLayout(deviceId: 'tv-1');
      expect(loaded, isEmpty);
    });

    test('persists and reloads positions by item id', () async {
      final repo = SharedPrefsLayoutRepository();
      const deviceId = 'samsung-192.168.1.10';

      await repo.saveLayout(
        deviceId: deviceId,
        positionsByItemId: {
          'mute': const LayoutPosition(col: 3, row: 5),
          'home': const LayoutPosition(col: 1, row: 0),
        },
      );

      final loaded = await repo.loadLayout(deviceId: deviceId);
      expect(loaded['mute']?.col, 3);
      expect(loaded['mute']?.row, 5);
      expect(loaded['home']?.col, 1);
      expect(loaded['home']?.row, 0);
    });

    test('overwrites prior layout for the same device', () async {
      final repo = SharedPrefsLayoutRepository();
      const deviceId = 'lg-10';

      await repo.saveLayout(
        deviceId: deviceId,
        positionsByItemId: {'menu': const LayoutPosition(col: 4, row: 0)},
      );
      await repo.saveLayout(
        deviceId: deviceId,
        positionsByItemId: {'menu': const LayoutPosition(col: 0, row: 8)},
      );

      final loaded = await repo.loadLayout(deviceId: deviceId);
      expect(loaded['menu']?.col, 0);
      expect(loaded['menu']?.row, 8);
    });

    test('skips entries with invalid position payloads', () async {
      SharedPreferences.setMockInitialValues({
        'remote_layout_v1_bad': '{"mute": "not-a-position"}',
      });
      final repo = SharedPrefsLayoutRepository();
      final loaded = await repo.loadLayout(deviceId: 'bad');
      expect(loaded, isEmpty);
    });

    test(
      'migrates a legacy layout without overwriting stable layout',
      () async {
        final repo = SharedPrefsLayoutRepository();
        await repo.saveLayout(
          deviceId: 'samsung-192.168.1.10',
          positionsByItemId: {'mute': const LayoutPosition(col: 3, row: 5)},
        );

        final didMigrate = await repo.migrateLayoutIdentity(
          legacyDeviceId: 'samsung-192.168.1.10',
          newDeviceId: 'samsung-udn-1',
        );

        expect(didMigrate, isTrue);
        final loaded = await repo.loadLayout(deviceId: 'samsung-udn-1');
        expect(loaded['mute']?.col, 3);
        expect(loaded['mute']?.row, 5);
        expect(
          (await repo.loadLayout(
            deviceId: 'samsung-192.168.1.10',
          ))['mute']?.col,
          3,
        );

        await repo.completeLayoutIdentityMigration(
          legacyDeviceId: 'samsung-192.168.1.10',
        );
        expect(
          await repo.loadLayout(deviceId: 'samsung-192.168.1.10'),
          isEmpty,
        );
      },
    );

    test('keeps an existing stable layout during migration', () async {
      final repo = SharedPrefsLayoutRepository();
      await repo.saveLayout(
        deviceId: 'samsung-192.168.1.10',
        positionsByItemId: {'mute': const LayoutPosition(col: 3, row: 5)},
      );
      await repo.saveLayout(
        deviceId: 'samsung-udn-1',
        positionsByItemId: {'mute': const LayoutPosition(col: 1, row: 2)},
      );

      final didMigrate = await repo.migrateLayoutIdentity(
        legacyDeviceId: 'samsung-192.168.1.10',
        newDeviceId: 'samsung-udn-1',
      );

      expect(didMigrate, isTrue);
      final loaded = await repo.loadLayout(deviceId: 'samsung-udn-1');
      expect(loaded['mute']?.col, 1);
      expect(loaded['mute']?.row, 2);
      await repo.completeLayoutIdentityMigration(
        legacyDeviceId: 'samsung-192.168.1.10',
      );
    });

    test('deletes a layout by device id', () async {
      final repo = SharedPrefsLayoutRepository();
      const deviceId = 'samsung-192.168.1.10';
      await repo.saveLayout(
        deviceId: deviceId,
        positionsByItemId: {'mute': const LayoutPosition(col: 3, row: 5)},
      );

      await repo.deleteLayout(deviceId: deviceId);

      expect(await repo.loadLayout(deviceId: deviceId), isEmpty);
    });

    test('persists and reloads zone', () async {
      final repo = SharedPrefsLayoutRepository();
      const deviceId = 'zone-device';

      await repo.saveLayout(
        deviceId: deviceId,
        positionsByItemId: {
          'mute': const LayoutPosition(col: 3, row: 5, zone: LayoutZone.drawer),
          'home': const LayoutPosition(col: 1, row: 0),
        },
      );

      final loaded = await repo.loadLayout(deviceId: deviceId);
      expect(loaded['mute']?.zone, LayoutZone.drawer);
      expect(loaded['home']?.zone, LayoutZone.grid);
    });

    test('legacy JSON with no zone key defaults to grid', () async {
      SharedPreferences.setMockInitialValues({
        'remote_layout_v1_legacy': '{"mute": {"col": 3, "row": 5}}',
      });
      final repo = SharedPrefsLayoutRepository();
      final loaded = await repo.loadLayout(deviceId: 'legacy');
      expect(loaded['mute']?.zone, LayoutZone.grid);
    });
  });
}
