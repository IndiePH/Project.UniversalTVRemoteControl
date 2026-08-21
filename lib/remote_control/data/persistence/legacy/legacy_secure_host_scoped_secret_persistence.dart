import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_host_scoped_secret_persistence.dart';

// LEGACY — retained for backward compatibility only.
//
// Device-encrypted local storage for per-host TV pairing secrets from the
// pre-stable-id era. New code MUST use [SecureDeviceScopedSecretPersistence].
// This class remains only so the lazy per-device migration can read secrets
// written by older app versions. Do not add new callers.

/// Device-encrypted local storage for per-host TV pairing secrets.
///
/// @deprecated Use [SecureDeviceScopedSecretPersistence] for all new code.
/// Uses platform secure storage (Android KeyStore-backed AES-GCM / iOS
/// Keychain) via [FlutterSecureStorage]. Data never leaves the device.
class LegacySecureHostScopedSecretPersistence
    implements LegacyHostScopedSecretPersistence {
  LegacySecureHostScopedSecretPersistence({
    required String keyPrefix,
    FlutterSecureStorage? storage,
  }) : _prefix = keyPrefix,
       _storage = storage ?? const FlutterSecureStorage();

  final String _prefix;
  final FlutterSecureStorage _storage;

  String _key(String host) =>
      LegacyInMemoryHostScopedSecretPersistence.storageKey(_prefix, host);

  @override
  Future<String?> read(String host) => _storage.read(key: _key(host));

  @override
  Future<void> write(String host, String value) =>
      _storage.write(key: _key(host), value: value);

  @override
  Future<void> delete(String host) => _storage.delete(key: _key(host));
}
