import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_gateway.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_host_scoped_secret_persistence.dart';

void main() {
  group('DeviceScopedSecretGateway', () {
    test(
      'writes to device-scoped store when stableId is registered for host',
      () async {
        final host = LegacyInMemoryHostScopedSecretPersistence();
        final device = InMemoryDeviceScopedSecretPersistence();
        final registry = DeviceIdentityRegistry()
          ..register('10.0.0.5', 'roku-1');
        final gateway = DeviceScopedSecretGateway(
          hostPersistence: host,
          devicePersistence: device,
          identityRegistry: registry,
        );

        await gateway.write('10.0.0.5', 'secret');

        expect(await device.read('roku-1'), 'secret');
        expect(await host.read('10.0.0.5'), isNull);
      },
    );

    test(
      'reads device-scoped value first when stableId is registered',
      () async {
        final host = LegacyInMemoryHostScopedSecretPersistence();
        final device = InMemoryDeviceScopedSecretPersistence();
        final registry = DeviceIdentityRegistry()
          ..register('10.0.0.5', 'roku-1');
        final gateway = DeviceScopedSecretGateway(
          hostPersistence: host,
          devicePersistence: device,
          identityRegistry: registry,
        );

        await device.write('roku-1', 'fresh');
        await host.write('10.0.0.5', 'stale-legacy');

        expect(await gateway.read('10.0.0.5'), 'fresh');
      },
    );

    test(
      'falls back to host-scoped value when device-scoped is empty',
      () async {
        final host = LegacyInMemoryHostScopedSecretPersistence();
        final device = InMemoryDeviceScopedSecretPersistence();
        final registry = DeviceIdentityRegistry()
          ..register('10.0.0.5', 'roku-1');
        final gateway = DeviceScopedSecretGateway(
          hostPersistence: host,
          devicePersistence: device,
          identityRegistry: registry,
        );

        await host.write('10.0.0.5', 'legacy');

        expect(await gateway.read('10.0.0.5'), 'legacy');
      },
    );

    test(
      'falls back to host-scoped when no stableId is registered (legacy)',
      () async {
        final host = LegacyInMemoryHostScopedSecretPersistence();
        final device = InMemoryDeviceScopedSecretPersistence();
        final registry = DeviceIdentityRegistry();
        final gateway = DeviceScopedSecretGateway(
          hostPersistence: host,
          devicePersistence: device,
          identityRegistry: registry,
        );

        await gateway.write('10.0.0.5', 'legacy-secret');

        expect(await host.read('10.0.0.5'), 'legacy-secret');
        expect(await device.read('roku-1'), isNull);
        expect(await gateway.read('10.0.0.5'), 'legacy-secret');
      },
    );

    test('delete clears both device-scoped and host-scoped entries', () async {
      final host = LegacyInMemoryHostScopedSecretPersistence();
      final device = InMemoryDeviceScopedSecretPersistence();
      final registry = DeviceIdentityRegistry()..register('10.0.0.5', 'roku-1');
      final gateway = DeviceScopedSecretGateway(
        hostPersistence: host,
        devicePersistence: device,
        identityRegistry: registry,
      );

      await device.write('roku-1', 'fresh');
      await host.write('10.0.0.5', 'stale-legacy');

      await gateway.delete('10.0.0.5');

      expect(await device.read('roku-1'), isNull);
      expect(await host.read('10.0.0.5'), isNull);
    });

    test(
      'degrades to pure host-keyed behaviour without registry/device persistence',
      () async {
        final host = LegacyInMemoryHostScopedSecretPersistence();
        final gateway = DeviceScopedSecretGateway(hostPersistence: host);

        await gateway.write('10.0.0.5', 'only');
        expect(await gateway.read('10.0.0.5'), 'only');
        await gateway.delete('10.0.0.5');
        expect(await gateway.read('10.0.0.5'), isNull);
      },
    );

    test(
      'survives IP change: secret written under stableId reads at new host',
      () async {
        final host = LegacyInMemoryHostScopedSecretPersistence();
        final device = InMemoryDeviceScopedSecretPersistence();
        final registry = DeviceIdentityRegistry()
          ..register('10.0.0.5', 'roku-1');
        final gateway = DeviceScopedSecretGateway(
          hostPersistence: host,
          devicePersistence: device,
          identityRegistry: registry,
        );

        // Pair at 10.0.0.5.
        await gateway.write('10.0.0.5', 'pairing-secret');
        // Router reboot: TV reappears at 10.0.0.9, same stable id.
        registry.register('10.0.0.9', 'roku-1');

        expect(await gateway.read('10.0.0.9'), 'pairing-secret');
      },
    );
  });
}
