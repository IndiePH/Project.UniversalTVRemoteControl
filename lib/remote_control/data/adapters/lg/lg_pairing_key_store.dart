import 'package:one_remote/remote_control/data/persistence/host_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/secure_host_scoped_secret_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the LG webOS client-key across app restarts per TV host.
///
/// Keys are stored in encrypted local storage on mobile (same as Samsung/Hisense).
/// Legacy values in [SharedPreferences] are migrated on first [keyForHost] read.
class LgPairingKeyStore {
  LgPairingKeyStore({HostScopedSecretPersistence? persistence})
    : _persistence =
          persistence ??
          SecureHostScopedSecretPersistence(keyPrefix: 'lg_client_key_');

  static const String _legacyKeyPrefix = 'lg_client_key_';

  final HostScopedSecretPersistence _persistence;

  Future<void> storeKeyForHost(String host, String key) async {
    final normalized = _normalizeHost(host);
    await _persistence.write(normalized, key);
    await _removeLegacyKeys(host, normalized);
  }

  Future<String?> keyForHost(String host) async {
    final normalized = _normalizeHost(host);
    final stored = await _persistence.read(normalized);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return _migrateLegacyKey(host, normalized);
  }

  Future<void> clearKeyForHost(String host) async {
    final normalized = _normalizeHost(host);
    await _persistence.delete(normalized);
    await _removeLegacyKeys(host, normalized);
  }

  Future<String?> _migrateLegacyKey(String host, String normalized) async {
    final prefs = await SharedPreferences.getInstance();
    var legacy = prefs.getString('$_legacyKeyPrefix$host');
    if ((legacy == null || legacy.isEmpty) && normalized != host) {
      legacy = prefs.getString('$_legacyKeyPrefix$normalized');
    }
    if (legacy == null || legacy.isEmpty) {
      return null;
    }
    await _persistence.write(normalized, legacy);
    await _removeLegacyKeys(host, normalized);
    return legacy;
  }

  Future<void> _removeLegacyKeys(String host, String normalized) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_legacyKeyPrefix$host');
    if (normalized != host) {
      await prefs.remove('$_legacyKeyPrefix$normalized');
    }
  }

  static String _normalizeHost(String host) => host.trim().toLowerCase();
}
