import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_host_scoped_secret_persistence.dart';

/// Bridges host-addressed secret access onto stable-id-keyed persistence.
///
/// Brand pairing secret stores receive a *host* from their transport clients
/// (resolved from the legacy IP-derived `TvDevice.id`). This gateway consults
/// the [DeviceIdentityRegistry] to translate that host into a stable id when
/// one is known, then:
///
///   * **read**  — prefers the [DeviceScopedSecretPersistence] entry keyed by
///     stable id, falling back to the [LegacyHostScopedSecretPersistence]
///     entry keyed by host (legacy devices paired before stable ids were
///     captured).
///   * **write** — stores under the stable id when one is known, otherwise
///     under the host (legacy path). A single authoritative copy is kept to
///     avoid divergence; the legacy host-keyed entry is left in place and
///     cleaned up later by Phase 4 reconciliation or an explicit [delete].
///   * **delete** — clears *both* the stable-id-keyed and host-keyed entries
///     so unpairing removes every copy regardless of which path wrote it.
///
/// When no registry or device-scoped persistence is wired (e.g. unit tests
/// that inject only an in-memory host-scoped store), the gateway degrades to
/// pure host-keyed behaviour, preserving existing semantics.
class DeviceScopedSecretGateway {
  DeviceScopedSecretGateway({
    required this._hostPersistence,
    this._devicePersistence,
    this._identityRegistry,
  });

  final LegacyHostScopedSecretPersistence _hostPersistence;
  final DeviceScopedSecretPersistence? _devicePersistence;
  final DeviceIdentityRegistry? _identityRegistry;

  bool get _deviceScopedEnabled =>
      _devicePersistence != null && _identityRegistry != null;

  String? _stableIdFor(String host) =>
      _identityRegistry?.stableIdForHost(host);

  Future<String?> read(String host) async {
    final normalized = _normalizeHost(host);
    if (_deviceScopedEnabled) {
      final stableId = _stableIdFor(normalized);
      if (stableId != null) {
        final deviceValue = await _devicePersistence!.read(stableId);
        if (deviceValue != null && deviceValue.isNotEmpty) {
          return deviceValue;
        }
      }
    }
    return _hostPersistence.read(normalized);
  }

  Future<void> write(String host, String value) async {
    final normalized = _normalizeHost(host);
    if (_deviceScopedEnabled) {
      final stableId = _stableIdFor(normalized);
      if (stableId != null) {
        await _devicePersistence!.write(stableId, value);
        return;
      }
    }
    await _hostPersistence.write(normalized, value);
  }

  Future<void> delete(String host) async {
    final normalized = _normalizeHost(host);
    if (_deviceScopedEnabled) {
      final stableId = _stableIdFor(normalized);
      if (stableId != null) {
        await _devicePersistence!.delete(stableId);
      }
    }
    await _hostPersistence.delete(normalized);
  }

  static String _normalizeHost(String host) => host.trim().toLowerCase();
}
