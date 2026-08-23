/// Local-only secret storage keyed by a TV's stable device identifier
/// (e.g. `samsung-<udn>`, `roku-<serial>`, `androidtv-<sha256>`).
///
/// Unlike [LegacyHostScopedSecretPersistence], keys here survive LAN IP changes
/// (router reboots, DHCP renewals) because they are derived from intrinsic
/// device identity rather than the ephemeral host address. Phase 3 of the
/// persistent-device-identity work re-keys pairing secrets onto this store.
abstract class DeviceScopedSecretPersistence {
  Future<String?> read(String stableId);

  Future<void> write(String stableId, String value);

  Future<void> delete(String stableId);
}

/// In-memory persistence for unit tests and fakes.
class InMemoryDeviceScopedSecretPersistence
    implements DeviceScopedSecretPersistence {
  final Map<String, String> _values = <String, String>{};

  static String storageKey(String prefix, String stableId) =>
      '$prefix${stableId.toLowerCase()}';

  @override
  Future<String?> read(String stableId) async =>
      _values[stableId.toLowerCase()];

  @override
  Future<void> write(String stableId, String value) async {
    _values[stableId.toLowerCase()] = value;
  }

  @override
  Future<void> delete(String stableId) async {
    _values.remove(stableId.toLowerCase());
  }
}
