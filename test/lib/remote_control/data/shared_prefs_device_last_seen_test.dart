import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/shared_prefs_device_repository.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and reads lastSeenAt', () async {
    final repository = SharedPrefsDeviceRepository();
    final timestamp = DateTime.utc(2026, 8, 21, 12);

    await repository.setLastSeenAt(
      deviceId: 'samsung-192.168.1.10',
      timestamp: timestamp,
    );

    expect(
      await repository.getLastSeenAt('samsung-192.168.1.10'),
      timestamp.toLocal(),
    );
  });

  test('identity migration copies and retires lastSeenAt', () async {
    const legacyId = 'samsung-192.168.1.10';
    const stableId = 'samsung-udn-1';
    const legacy = TvDevice(
      id: legacyId,
      displayName: 'Living Room TV',
      brand: TvBrand.samsung,
      capabilities: {DeviceCapability.keyCommands},
      host: '192.168.1.10',
    );
    final timestamp = DateTime.utc(2026, 8, 1);
    SharedPreferences.setMockInitialValues({
      'device_ids_v1': jsonEncode([legacyId]),
      'device_v1_$legacyId': jsonEncode(legacy.toJson()),
      'last_seen_at_v1_$legacyId': timestamp.millisecondsSinceEpoch,
    });
    final repository = SharedPrefsDeviceRepository();

    final migrated = await repository.migrateDeviceIdentity(
      legacyId: legacyId,
      device: legacy.copyWith(id: stableId),
    );

    expect(migrated, isTrue);
    expect(await repository.getLastSeenAt(stableId), timestamp.toLocal());
    expect(await repository.getLastSeenAt(legacyId), isNull);
  });

  test('removeSavedDevice removes lastSeenAt metadata', () async {
    final repository = SharedPrefsDeviceRepository();
    const deviceId = 'samsung-192.168.1.10';
    await repository.setLastSeenAt(
      deviceId: deviceId,
      timestamp: DateTime.utc(2026, 8, 21),
    );

    await repository.removeSavedDevice(deviceId);

    expect(await repository.getLastSeenAt(deviceId), isNull);
  });
}
