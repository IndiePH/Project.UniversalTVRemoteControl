import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_pairing_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LgPairingKeyStore: stored key survives a fresh getInstance() call', () async {
    final store = LgPairingKeyStore();
    await store.storeKeyForHost('192.168.1.10', 'abc123');

    final retrieved = await store.keyForHost('192.168.1.10');
    expect(retrieved, 'abc123');
  });

  test('LgPairingKeyStore: keyForHost returns null when no key is stored', () async {
    final store = LgPairingKeyStore();
    expect(await store.keyForHost('192.168.1.99'), isNull);
  });

  test('LgPairingKeyStore: clearKeyForHost removes the stored key', () async {
    final store = LgPairingKeyStore();
    await store.storeKeyForHost('192.168.1.10', 'abc123');
    await store.clearKeyForHost('192.168.1.10');

    expect(await store.keyForHost('192.168.1.10'), isNull);
  });

  test('LgPairingKeyStore: keys are isolated per host', () async {
    final store = LgPairingKeyStore();
    await store.storeKeyForHost('192.168.1.10', 'key-for-tv1');
    await store.storeKeyForHost('192.168.1.20', 'key-for-tv2');

    expect(await store.keyForHost('192.168.1.10'), 'key-for-tv1');
    expect(await store.keyForHost('192.168.1.20'), 'key-for-tv2');
  });

  test('LgPairingKeyStore: clearing one host does not affect another', () async {
    final store = LgPairingKeyStore();
    await store.storeKeyForHost('192.168.1.10', 'key-for-tv1');
    await store.storeKeyForHost('192.168.1.20', 'key-for-tv2');
    await store.clearKeyForHost('192.168.1.10');

    expect(await store.keyForHost('192.168.1.10'), isNull);
    expect(await store.keyForHost('192.168.1.20'), 'key-for-tv2');
  });
}
