import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_pairing_auth_store.dart';
import 'package:one_remote/remote_control/data/persistence/host_scoped_secret_persistence.dart';

void main() {
  group('HisensePairingAuthStore', () {
    test('markHostPaired survives a new store instance', () async {
      const host = '192.168.1.30';
      final persistence = InMemoryHostScopedSecretPersistence();
      final writer = HisensePairingAuthStore(persistence: persistence);
      await writer.markHostPaired(host);

      final reader = HisensePairingAuthStore(persistence: persistence);
      expect(await reader.isHostPaired(host), isTrue);
    });

    test('clearHost removes persisted pairing flag', () async {
      const host = '192.168.1.31';
      final persistence = InMemoryHostScopedSecretPersistence();
      final store = HisensePairingAuthStore(persistence: persistence);
      await store.markHostPaired(host);
      await store.clearHost(host);

      expect(await store.isHostPaired(host), isFalse);
    });
  });
}
