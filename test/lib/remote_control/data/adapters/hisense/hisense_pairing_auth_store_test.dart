import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_pairing_auth_store.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_host_scoped_secret_persistence.dart';

void main() {
  group('HisensePairingAuthStore', () {
    test('markHostPaired survives a new store instance', () async {
      const host = '192.168.1.30';
      final persistence = LegacyInMemoryHostScopedSecretPersistence();
      final writer = HisensePairingAuthStore(persistence: persistence);
      await writer.markHostPaired(host);

      final reader = HisensePairingAuthStore(persistence: persistence);
      expect(await reader.isHostPaired(host), isTrue);
    });

    test('clearHost removes persisted pairing flag', () async {
      const host = '192.168.1.31';
      final persistence = LegacyInMemoryHostScopedSecretPersistence();
      final store = HisensePairingAuthStore(persistence: persistence);
      await store.markHostPaired(host);
      await store.clearHost(host);

      expect(await store.isHostPaired(host), isFalse);
    });
  });

  group('HisensePairingAuthStore stable-id re-keying', () {
    HisensePairingAuthStore storeWithRegistry(
      LegacyInMemoryHostScopedSecretPersistence host,
      InMemoryDeviceScopedSecretPersistence device,
      DeviceIdentityRegistry registry,
    ) => HisensePairingAuthStore(
      persistence: host,
      devicePersistence: device,
      identityRegistry: registry,
    );

    test('markHostPaired persists under stableId when registered', () async {
      final host = LegacyInMemoryHostScopedSecretPersistence();
      final device = InMemoryDeviceScopedSecretPersistence();
      final registry = DeviceIdentityRegistry()
        ..register('192.168.1.30', 'hisense-udn-1');
      final writer = storeWithRegistry(host, device, registry);

      await writer.markHostPaired('192.168.1.30');

      expect(await device.read('hisense-udn-1'), '1');
      expect(await host.read('192.168.1.30'), isNull);
    });

    test('isHostPaired reads stableId entry after IP change', () async {
      final host = LegacyInMemoryHostScopedSecretPersistence();
      final device = InMemoryDeviceScopedSecretPersistence();
      final registry = DeviceIdentityRegistry()
        ..register('192.168.1.30', 'hisense-udn-1');
      final writer = storeWithRegistry(host, device, registry);
      await writer.markHostPaired('192.168.1.30');

      registry.register('192.168.1.99', 'hisense-udn-1');
      final reader = storeWithRegistry(host, device, registry);

      expect(await reader.isHostPaired('192.168.1.99'), isTrue);
    });

    test('clearHost removes the stableId entry', () async {
      final host = LegacyInMemoryHostScopedSecretPersistence();
      final device = InMemoryDeviceScopedSecretPersistence();
      final registry = DeviceIdentityRegistry()
        ..register('192.168.1.30', 'hisense-udn-1');
      final store = storeWithRegistry(host, device, registry);
      await store.markHostPaired('192.168.1.30');

      await store.clearHost('192.168.1.30');

      expect(await device.read('hisense-udn-1'), isNull);
    });
  });
}
