import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:one_remote/remote_control/data/persistence/host_scoped_secret_persistence.dart';

/// Device-encrypted local storage for per-host TV pairing secrets.
///
/// Uses platform secure storage (Android KeyStore-backed AES-GCM / iOS Keychain)
/// via [FlutterSecureStorage]. Data never leaves the device.
class SecureHostScopedSecretPersistence implements HostScopedSecretPersistence {
  SecureHostScopedSecretPersistence({
    required String keyPrefix,
    FlutterSecureStorage? storage,
  }) : _prefix = keyPrefix,
       _storage = storage ?? const FlutterSecureStorage();

  final String _prefix;
  final FlutterSecureStorage _storage;

  String _key(String host) =>
      InMemoryHostScopedSecretPersistence.storageKey(_prefix, host);

  @override
  Future<String?> read(String host) => _storage.read(key: _key(host));

  @override
  Future<void> write(String host, String value) =>
      _storage.write(key: _key(host), value: value);

  @override
  Future<void> delete(String host) => _storage.delete(key: _key(host));
}
