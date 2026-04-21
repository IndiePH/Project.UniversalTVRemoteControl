import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg/real_lg_pairing_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('RealLgPairingKeyStore: stored key survives a fresh getInstance() call', () async {
    final store = RealLgPairingKeyStore();
    await store.storeKeyForHost('192.168.1.10', 'abc123');

    final retrieved = await store.keyForHost('192.168.1.10');
    expect(retrieved, 'abc123');
  });

  test('RealLgPairingKeyStore: keyForHost returns null when no key is stored', () async {
    final store = RealLgPairingKeyStore();
    expect(await store.keyForHost('192.168.1.99'), isNull);
  });

  test('RealLgPairingKeyStore: clearKeyForHost removes the stored key', () async {
    final store = RealLgPairingKeyStore();
    await store.storeKeyForHost('192.168.1.10', 'abc123');
    await store.clearKeyForHost('192.168.1.10');

    expect(await store.keyForHost('192.168.1.10'), isNull);
  });

  test('RealLgPairingKeyStore: keys are isolated per host', () async {
    final store = RealLgPairingKeyStore();
    await store.storeKeyForHost('192.168.1.10', 'key-for-tv1');
    await store.storeKeyForHost('192.168.1.20', 'key-for-tv2');

    expect(await store.keyForHost('192.168.1.10'), 'key-for-tv1');
    expect(await store.keyForHost('192.168.1.20'), 'key-for-tv2');
  });

  test('RealLgPairingKeyStore: clearing one host does not affect another', () async {
    final store = RealLgPairingKeyStore();
    await store.storeKeyForHost('192.168.1.10', 'key-for-tv1');
    await store.storeKeyForHost('192.168.1.20', 'key-for-tv2');
    await store.clearKeyForHost('192.168.1.10');

    expect(await store.keyForHost('192.168.1.10'), isNull);
    expect(await store.keyForHost('192.168.1.20'), 'key-for-tv2');
  });
}
