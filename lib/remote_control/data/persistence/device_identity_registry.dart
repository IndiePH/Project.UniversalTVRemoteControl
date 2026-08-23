/// In-memory index mapping a TV's current LAN host to its stable device
/// identifier and back.
///
/// Phase 3 of the persistent-device-identity work keeps pairing secrets keyed
/// by stable id (see [DeviceScopedSecretPersistence]). Transport clients,
/// however, still address devices by host (resolved from the legacy IP-derived
/// `TvDevice.id`). This registry bridges the two: brand secret stores consult
/// it to translate the host they receive from a transport into the stable id
/// under which the secret is persisted.
///
/// Population points:
///   * [SharedPrefsDeviceRepository] registers every loaded saved device's
///     `resolvedHost -> stableId` so cold-start reconnects find their secrets.
///   * [BrandRoutedRemoteCommandService.preparePairing] registers the enriched
///     device's `resolvedHost -> stableId` so the pairing handshake (which
///     writes the secret asynchronously after enrichment) stores it under the
///     stable id.
///   * Phase 4 reconciliation re-registers when a TV is rediscovered at a new
///     host, making the new host the "current" one returned by
///     [hostForStableId].
///
/// The registry is intentionally in-memory and session-scoped; it carries no
/// secrets and is rebuilt from the saved-device list on each launch.
class DeviceIdentityRegistry {
  final Map<String, String> _byHost = <String, String>{};
  // Insertion-ordered so the last entry is the most recently registered host.
  final Map<String, List<String>> _hostsByStableId = <String, List<String>>{};

  /// Registers [host] as the current LAN address of [stableId].
  /// Overwrites any prior stable id bound to [host], and makes [host] the
  /// most-recent host for [stableId] (so [hostForStableId] returns it).
  void register(String host, String stableId) {
    final h = _normalizeHost(host);
    final s = stableId.trim();
    if (h.isEmpty || s.isEmpty) return;

    final previous = _byHost[h];
    if (previous != null && previous != s) {
      _hostsByStableId[previous]?.remove(h);
      if (_hostsByStableId[previous]?.isEmpty ?? false) {
        _hostsByStableId.remove(previous);
      }
    }
    _byHost[h] = s;
    final hosts = _hostsByStableId.putIfAbsent(s, () => <String>[]);
    hosts.remove(h);
    hosts.add(h);
  }

  /// Returns the stable id currently bound to [host], or null when no mapping
  /// is known (e.g. a legacy device paired before stable ids were captured).
  String? stableIdForHost(String host) => _byHost[_normalizeHost(host)];

  /// Returns the most recently registered LAN host for [stableId], or null
  /// when no host is known for it. Used by transport host resolution once
  /// `TvDevice.id` becomes the stable id (Phase 4 step 6).
  String? hostForStableId(String stableId) {
    final hosts = _hostsByStableId[stableId.trim()];
    if (hosts == null || hosts.isEmpty) return null;
    return hosts.last;
  }

  /// Drops the [host] -> stableId binding without touching the reverse index
  /// entry for the stable id (other hosts may still map to it).
  void forgetHost(String host) {
    final h = _normalizeHost(host);
    final s = _byHost.remove(h);
    if (s != null) {
      _hostsByStableId[s]?.remove(h);
      if (_hostsByStableId[s]?.isEmpty ?? false) {
        _hostsByStableId.remove(s);
      }
    }
  }

  /// Drops every binding associated with [stableId] (all known hosts for it).
  void forgetStableId(String stableId) {
    final s = stableId.trim();
    final hosts = _hostsByStableId.remove(s);
    if (hosts == null) return;
    for (final h in hosts) {
      if (_byHost[h] == s) _byHost.remove(h);
    }
  }

  static String _normalizeHost(String host) => host.trim().toLowerCase();
}
