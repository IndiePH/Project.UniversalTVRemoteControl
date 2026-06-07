import 'package:one_remote/remote_control/data/persistence/host_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/secure_host_scoped_secret_persistence.dart';

/// Persists Hisense VIDAA MQTT PIN authorization per TV host.
///
/// Hisense has no long-lived token; the TV remembers PIN acceptance per device.
/// We persist that the user completed PIN entry for this host so cold starts
/// can reconnect without re-prompting until [clearHost].
class HisensePairingAuthStore {
  HisensePairingAuthStore({HostScopedSecretPersistence? persistence})
    : _persistence =
          persistence ??
          SecureHostScopedSecretPersistence(keyPrefix: 'hisense_mqtt_paired_');

  static const String _pairedMarker = '1';

  final HostScopedSecretPersistence _persistence;

  Future<bool> isHostPaired(String host) async {
    final stored = await _persistence.read(_normalizeHost(host));
    return stored == _pairedMarker;
  }

  Future<void> markHostPaired(String host) =>
      _persistence.write(_normalizeHost(host), _pairedMarker);

  Future<void> clearHost(String host) =>
      _persistence.delete(_normalizeHost(host));

  static String _normalizeHost(String host) => host.trim().toLowerCase();
}
