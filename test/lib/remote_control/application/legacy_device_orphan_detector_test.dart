import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/device_last_seen_repository.dart';
import 'package:one_remote/remote_control/application/legacy_device_orphan_detector.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  const legacy = TvDevice(
    id: 'samsung-192.168.1.10',
    displayName: 'Living Room TV',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands},
    host: '192.168.1.10',
  );
  const stable = TvDevice(
    id: 'samsung-udn-1',
    displayName: 'Stable TV',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands},
    host: '192.168.1.11',
  );

  test(
    'starts the grace period when a legacy record is first observed',
    () async {
      final repository = _FakeDeviceLastSeenRepository();
      final now = DateTime.utc(2026, 8, 21);

      final candidates =
          await LegacyDeviceOrphanDetector.updateAndFindCandidates(
            savedDevices: [legacy],
            discoveredDevices: const [],
            activeDeviceId: null,
            repository: repository,
            now: now,
          );

      expect(candidates, isEmpty);
      expect(await repository.getLastSeenAt(legacy.id), now);
    },
  );

  test(
    'refreshes a legacy timestamp when the host and brand are discovered',
    () async {
      final repository = _FakeDeviceLastSeenRepository(
        values: {legacy.id: DateTime.utc(2026, 7, 1)},
      );
      final now = DateTime.utc(2026, 8, 21);
      const discoveredStable = TvDevice(
        id: 'samsung-udn-1',
        displayName: 'Living Room TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
        host: '192.168.1.10',
      );

      final candidates =
          await LegacyDeviceOrphanDetector.updateAndFindCandidates(
            savedDevices: [legacy],
            discoveredDevices: [discoveredStable],
            activeDeviceId: null,
            repository: repository,
            now: now,
          );

      expect(candidates, isEmpty);
      expect(await repository.getLastSeenAt(legacy.id), now);
    },
  );

  test(
    'returns only non-active legacy records past the grace period',
    () async {
      final repository = _FakeDeviceLastSeenRepository(
        values: {
          legacy.id: DateTime.utc(2026, 7, 1),
          stable.id: DateTime.utc(2026, 7, 1),
        },
      );
      final now = DateTime.utc(2026, 8, 21);

      final candidates =
          await LegacyDeviceOrphanDetector.updateAndFindCandidates(
            savedDevices: [legacy, stable],
            discoveredDevices: const [],
            activeDeviceId: stable.id,
            repository: repository,
            now: now,
          );

      expect(candidates, [legacy]);
    },
  );

  test('does not return an active legacy record', () async {
    final repository = _FakeDeviceLastSeenRepository(
      values: {legacy.id: DateTime.utc(2026, 7, 1)},
    );
    final now = DateTime.utc(2026, 8, 21);

    final candidates = await LegacyDeviceOrphanDetector.updateAndFindCandidates(
      savedDevices: [legacy],
      discoveredDevices: const [],
      activeDeviceId: legacy.id,
      repository: repository,
      now: now,
    );

    expect(candidates, isEmpty);
  });
}

class _FakeDeviceLastSeenRepository implements DeviceLastSeenRepository {
  _FakeDeviceLastSeenRepository({
    Map<String, DateTime> values = const <String, DateTime>{},
  }) : _values = {...values};

  final Map<String, DateTime> _values;

  @override
  Future<DateTime?> getLastSeenAt(String deviceId) async => _values[deviceId];

  @override
  Future<void> setLastSeenAt({
    required String deviceId,
    required DateTime timestamp,
  }) async {
    _values[deviceId] = timestamp;
  }
}
