import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/shared_prefs_device_repository.dart';
import 'package:one_remote/remote_control/data/shared_prefs_layout_repository.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/layout_position.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

TvDevice _device({
  required String id,
  required String host,
  required TvBrand brand,
}) {
  return TvDevice(
    id: id,
    displayName: '${brand.displayName} TV ($host)',
    brand: brand,
    capabilities: const <DeviceCapability>{},
    host: host,
  );
}

/// Minimal fake that records saveDevice calls so the test can assert which
/// devices were persisted by reconciliation.
class _RecordingDeviceRepository implements DeviceRepository {
  _RecordingDeviceRepository(this._saved);

  final List<TvDevice> _saved;
  final List<TvDevice> savedCalls = [];

  @override
  Future<List<TvDevice>> getSavedDevices() async => List.of(_saved);

  @override
  Future<TvDevice?> getLastUsedDevice() async => null;

  @override
  Future<List<String>> getRecentManualIps() async => const [];

  @override
  Future<DateTime?> getLastSuccessfulPairingAt(String deviceId) async => null;

  @override
  Future<void> saveDevice(TvDevice device) async {
    savedCalls.add(device);
  }

  @override
  Future<void> removeSavedDevice(String deviceId) async {}

  @override
  Future<void> saveRecentManualIp(String ipAddress) async {}

  @override
  Future<void> setLastSuccessfulPairingAt({
    required String deviceId,
    required DateTime timestamp,
  }) async {}

  @override
  Future<void> setLastUsedDevice(String deviceId) async {}

  @override
  Future<void> saveDeviceSystemInfo(
    String deviceId,
    Map<String, dynamic> info,
  ) async {}

  @override
  Future<Map<String, dynamic>?> getDeviceSystemInfo(String deviceId) async =>
      null;
}

void main() {
  group('PairingPageData.reconcileDiscovery', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'persists saved device with refreshed host when TV moved IPs',
      () async {
        final registry = DeviceIdentityRegistry();
        final saved = [
          _device(
            id: 'samsung-uuid-1',
            host: '192.168.1.10',
            brand: TvBrand.samsung,
          ),
        ];
        final repo = _RecordingDeviceRepository(saved);
        final discovered = [
          _device(
            id: 'samsung-uuid-1',
            host: '192.168.1.99',
            brand: TvBrand.samsung,
          ),
        ];

        await PairingPageData.reconcileDiscovery(
          discovered: discovered,
          saved: saved,
          identityRegistry: registry,
          deviceRepository: repo,
        );

        expect(repo.savedCalls, hasLength(1));
        expect(repo.savedCalls.single.id, 'samsung-uuid-1');
        expect(repo.savedCalls.single.host, '192.168.1.99');
        // Registry reflects the new host for in-session transport resolution.
        expect(registry.hostForStableId('samsung-uuid-1'), '192.168.1.99');
      },
    );

    test('is a no-op when no registry is wired (legacy/tests)', () async {
      final saved = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];
      final repo = _RecordingDeviceRepository(saved);
      final discovered = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.99',
          brand: TvBrand.samsung,
        ),
      ];

      await PairingPageData.reconcileDiscovery(
        discovered: discovered,
        saved: saved,
        identityRegistry: null,
        deviceRepository: repo,
      );

      expect(repo.savedCalls, isEmpty);
    });

    test('does not persist when the host is unchanged', () async {
      final registry = DeviceIdentityRegistry();
      final saved = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];
      final repo = _RecordingDeviceRepository(saved);
      final discovered = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];

      await PairingPageData.reconcileDiscovery(
        discovered: discovered,
        saved: saved,
        identityRegistry: registry,
        deviceRepository: repo,
      );

      expect(repo.savedCalls, isEmpty);
    });

    test(
      'migrates legacy device and layout on exact host/brand match',
      () async {
        final registry = DeviceIdentityRegistry();
        final deviceRepository = SharedPrefsDeviceRepository(
          identityRegistry: registry,
        );
        final layoutRepository = SharedPrefsLayoutRepository();
        final legacy = _device(
          id: 'samsung-192.168.1.10',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        );
        await deviceRepository.saveDevice(legacy);
        await layoutRepository.saveLayout(
          deviceId: legacy.id,
          positionsByItemId: {'mute': const LayoutPosition(col: 2, row: 4)},
        );

        await PairingPageData.reconcileDiscovery(
          discovered: [
            _device(
              id: 'samsung-udn-1',
              host: '192.168.1.10',
              brand: TvBrand.samsung,
            ),
          ],
          saved: [legacy],
          identityRegistry: registry,
          deviceRepository: deviceRepository,
          layoutRepository: layoutRepository,
        );

        final saved = await deviceRepository.getSavedDevices();
        expect(saved, hasLength(1));
        expect(saved.single.id, 'samsung-udn-1');
        expect(
          (await layoutRepository.loadLayout(
            deviceId: 'samsung-udn-1',
          ))['mute']?.col,
          2,
        );
        expect(registry.hostForStableId('samsung-udn-1'), '192.168.1.10');
      },
    );
  });
}
