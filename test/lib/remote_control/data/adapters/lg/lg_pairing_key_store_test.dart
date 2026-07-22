import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_pairing_key_store.dart';
import 'package:one_remote/remote_control/data/persistence/host_scoped_secret_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

LgPairingKeyStore _store({HostScopedSecretPersistence? persistence}) =>
    LgPairingKeyStore(persistence: persistence);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LgPairingKeyStore', () {
    test('stored key survives a new store instance', () async {
      const host = '192.168.1.10';
      final persistence = InMemoryHostScopedSecretPersistence();
      final writer = _store(persistence: persistence);
      await writer.storeKeyForHost(host, 'abc123');

      final reader = _store(persistence: persistence);
      expect(await reader.keyForHost(host), 'abc123');
    });

    test('keyForHost returns null when no key is stored', () async {
      final store = _store(persistence: InMemoryHostScopedSecretPersistence());
      expect(await store.keyForHost('192.168.1.99'), isNull);
    });

    test('clearKeyForHost removes the stored key', () async {
      const host = '192.168.1.10';
      final persistence = InMemoryHostScopedSecretPersistence();
      final store = _store(persistence: persistence);
      await store.storeKeyForHost(host, 'abc123');
      await store.clearKeyForHost(host);

      expect(await store.keyForHost(host), isNull);
    });

    test('keys are isolated per host', () async {
      final persistence = InMemoryHostScopedSecretPersistence();
      final store = _store(persistence: persistence);
      await store.storeKeyForHost('192.168.1.10', 'key-for-tv1');
      await store.storeKeyForHost('192.168.1.20', 'key-for-tv2');

      expect(await store.keyForHost('192.168.1.10'), 'key-for-tv1');
      expect(await store.keyForHost('192.168.1.20'), 'key-for-tv2');
    });

    test('clearing one host does not affect another', () async {
      final persistence = InMemoryHostScopedSecretPersistence();
      final store = _store(persistence: persistence);
      await store.storeKeyForHost('192.168.1.10', 'key-for-tv1');
      await store.storeKeyForHost('192.168.1.20', 'key-for-tv2');
      await store.clearKeyForHost('192.168.1.10');

      expect(await store.keyForHost('192.168.1.10'), isNull);
      expect(await store.keyForHost('192.168.1.20'), 'key-for-tv2');
    });

    test('migrates legacy SharedPreferences key on read', () async {
      const host = '192.168.1.15';
      SharedPreferences.setMockInitialValues({
        'lg_client_key_$host': 'legacy-key',
      });
      final persistence = InMemoryHostScopedSecretPersistence();
      final store = _store(persistence: persistence);

      expect(await store.keyForHost(host), 'legacy-key');
      expect(
        SharedPreferences.getInstance().then(
          (p) => p.getString('lg_client_key_$host'),
        ),
        completion(isNull),
      );
      expect(await persistence.read(host), 'legacy-key');
    });

    test('storeKeyForHost removes legacy SharedPreferences entry', () async {
      const host = '192.168.1.16';
      SharedPreferences.setMockInitialValues({
        'lg_client_key_$host': 'old-key',
      });
      final store = _store(persistence: InMemoryHostScopedSecretPersistence());
      await store.storeKeyForHost(host, 'new-key');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lg_client_key_$host'), isNull);
      expect(await store.keyForHost(host), 'new-key');
    });
  });
}
