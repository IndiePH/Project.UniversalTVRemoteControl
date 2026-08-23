// LEGACY — retained for backward compatibility only.
//
// Host-keyed (IP-addressed) secret storage from the pre-stable-id era. New
// code MUST use the stable-id-keyed stores in the parent `persistence/`
// package (DeviceScopedSecretPersistence and friends). This file is kept so
// the lazy per-device migration and the legacy fallback path inside
// DeviceScopedSecretGateway can still read secrets written by older app
// versions. Do not add new callers.

/// Local-only secret storage keyed by TV LAN host (IPv4).
///
/// @deprecated Use [DeviceScopedSecretPersistence] for all new code. This
/// abstraction remains only to read secrets written by legacy app versions
/// that keyed pairing secrets off the (mutable) LAN IP.
abstract class LegacyHostScopedSecretPersistence {
  Future<String?> read(String host);

  Future<void> write(String host, String value);

  Future<void> delete(String host);
}

/// In-memory persistence for unit tests and fakes.
///
/// @deprecated Use [InMemoryDeviceScopedSecretPersistence] for new tests.
/// This class remains for tests that exercise the legacy host-keyed fallback.
class LegacyInMemoryHostScopedSecretPersistence
    implements LegacyHostScopedSecretPersistence {
  final Map<String, String> _values = <String, String>{};

  static String storageKey(String prefix, String host) =>
      '$prefix${host.toLowerCase()}';

  @override
  Future<String?> read(String host) async => _values[host.toLowerCase()];

  @override
  Future<void> write(String host, String value) async {
    _values[host.toLowerCase()] = value;
  }

  @override
  Future<void> delete(String host) async {
    _values.remove(host.toLowerCase());
  }
}
