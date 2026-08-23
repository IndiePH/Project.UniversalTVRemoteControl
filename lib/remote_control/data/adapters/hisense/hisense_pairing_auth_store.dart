import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_gateway.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_host_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_secure_host_scoped_secret_persistence.dart';

/// Persists Hisense VIDAA MQTT PIN authorization per TV host.
///
/// Hisense has no long-lived token; the TV remembers PIN acceptance per device.
/// We persist that the user completed PIN entry for this host so cold starts
/// can reconnect without re-prompting until [clearHost].
///
/// Phase 3: when a stable id is known for a host (via [DeviceIdentityRegistry]),
/// the marker is persisted under that stable id through
/// [DeviceScopedSecretGateway] so it survives LAN IP changes. Legacy host-keyed
/// entries are still read as a fallback for devices paired before stable ids
/// were captured.
class HisensePairingAuthStore {
  HisensePairingAuthStore({
    LegacyHostScopedSecretPersistence? persistence,
    DeviceScopedSecretPersistence? devicePersistence,
    DeviceIdentityRegistry? identityRegistry,
  }) : _gateway = DeviceScopedSecretGateway(
         hostPersistence:
             persistence ??
             LegacySecureHostScopedSecretPersistence(
               keyPrefix: 'hisense_mqtt_paired_',
             ),
         devicePersistence: devicePersistence,
         identityRegistry: identityRegistry,
       );

  static const String _pairedMarker = '1';

  final DeviceScopedSecretGateway _gateway;

  Future<bool> isHostPaired(String host) async {
    final stored = await _gateway.read(host);
    return stored == _pairedMarker;
  }

  Future<void> markHostPaired(String host) =>
      _gateway.write(host, _pairedMarker);

  Future<void> clearHost(String host) => _gateway.delete(host);
}
