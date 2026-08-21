import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_persistence.dart';

/// Device-encrypted local storage for per-stable-id TV pairing secrets.
///
/// Uses platform secure storage (Android KeyStore-backed AES-GCM / iOS Keychain)
/// via [FlutterSecureStorage]. Data never leaves the device. Keys are derived
/// from a TV's stable identifier so secrets survive LAN IP changes.
class SecureDeviceScopedSecretPersistence
    implements DeviceScopedSecretPersistence {
  SecureDeviceScopedSecretPersistence({
    required String keyPrefix,
    FlutterSecureStorage? storage,
  }) : _prefix = keyPrefix,
       _storage = storage ?? const FlutterSecureStorage();

  final String _prefix;
  final FlutterSecureStorage _storage;

  String _key(String stableId) =>
      InMemoryDeviceScopedSecretPersistence.storageKey(_prefix, stableId);

  @override
  Future<String?> read(String stableId) => _storage.read(key: _key(stableId));

  @override
  Future<void> write(String stableId, String value) =>
      _storage.write(key: _key(stableId), value: value);

  @override
  Future<void> delete(String stableId) =>
      _storage.delete(key: _key(stableId));
}
