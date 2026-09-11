import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_certificate_store.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_legacy_sha256_id_migrator.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  // The actual certificate connection (_migrateOne's SecureSocket.connect path) requires a real
  // TLS server and is intentionally not covered here, consistent with this codebase's existing,
  // logged tech debt for AndroidTvTcpTransportClient.discoverStableIdAtHost. What's covered: the
  // pure filtering/guard logic that decides whether a connection is even attempted -- the part
  // that's actually unit-testable without real network I/O.

  final certStore = AndroidTvCertificateStore();

  TvDevice androidTv({required String id, String host = '192.168.1.20'}) =>
      TvDevice(
        id: id,
        displayName: 'Living Room TV',
        brand: TvBrand.androidTv,
        capabilities: const {DeviceCapability.keyCommands},
        host: host,
      );

  group('AndroidTvLegacySha256IdMigrator.migrate', () {
    test(
      'does nothing when no saved device uses the legacy sha256 id format',
      () async {
        final repository = _RecordingDeviceRepository();
        await AndroidTvLegacySha256IdMigrator.migrate(
          discovered: [androidTv(id: 'androidtv-aa:bb:cc:dd:ee:ff')],
          saved: [
            androidTv(
              id: 'androidtv-aa:bb:cc:dd:ee:ff',
            ), // already mac-based, not legacy
            androidTv(id: 'androidtv-192.168.1.20'), // ip-derived, not legacy
          ],
          certStore: certStore,
          repository: repository,
        );

        expect(repository.savedCalls, isEmpty);
      },
    );

    test(
      'ignores non-Android-TV saved devices even if their id happens to look sha-shaped',
      () async {
        final repository = _RecordingDeviceRepository();
        final shaLikeId = 'androidtv-${'a' * 64}';
        await AndroidTvLegacySha256IdMigrator.migrate(
          discovered: [],
          saved: [
            TvDevice(
              id: shaLikeId,
              displayName: 'Not Actually Android TV',
              brand: TvBrand.samsung,
              capabilities: const {DeviceCapability.keyCommands},
            ),
          ],
          certStore: certStore,
          repository: repository,
        );

        expect(repository.savedCalls, isEmpty);
      },
    );

    test(
      'skips a discovered device with a blank host without attempting a connection',
      () async {
        final repository = _RecordingDeviceRepository();
        final legacyId = 'androidtv-${'a' * 64}';

        // If this reached the connection step it would hang/timeout against a real socket; the
        // guard must return before that, so this test completing quickly is itself the assertion.
        await AndroidTvLegacySha256IdMigrator.migrate(
          discovered: [androidTv(id: 'androidtv-192.168.1.99', host: '')],
          saved: [androidTv(id: legacyId)],
          certStore: certStore,
          repository: repository,
        );

        expect(repository.savedCalls, isEmpty);
      },
    );

    test('ignores discovered devices of other brands', () async {
      final repository = _RecordingDeviceRepository();
      final legacyId = 'androidtv-${'a' * 64}';
      await AndroidTvLegacySha256IdMigrator.migrate(
        discovered: [
          TvDevice(
            id: 'samsung-192.168.1.30',
            displayName: 'Bedroom Samsung',
            brand: TvBrand.samsung,
            capabilities: const {DeviceCapability.keyCommands},
            host: '192.168.1.30',
          ),
        ],
        saved: [androidTv(id: legacyId)],
        certStore: certStore,
        repository: repository,
      );

      expect(repository.savedCalls, isEmpty);
    });
  });
}

class _RecordingDeviceRepository implements DeviceRepository {
  final List<TvDevice> savedCalls = [];

  @override
  Future<List<TvDevice>> getSavedDevices() async => const [];

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
