/// Local-only secret storage keyed by TV LAN host (IPv4).
abstract class HostScopedSecretPersistence {
  Future<String?> read(String host);

  Future<void> write(String host, String value);

  Future<void> delete(String host);
}

/// In-memory persistence for unit tests and fakes.
class InMemoryHostScopedSecretPersistence implements HostScopedSecretPersistence {
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
