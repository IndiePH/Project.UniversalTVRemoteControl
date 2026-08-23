import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Matches freshly discovered TVs against persisted saved devices by stable
/// identifier and produces the set of saved-device updates needed when a TV
/// has moved to a new LAN host (e.g. after a router reboot re-issued IPs).
///
/// This is the core of Phase 4 step 3. Identity is the stable id; the host is
/// treated as mutable display/transport metadata that reconciliation refreshes.
///
/// The service is intentionally pure with respect to persistence: it returns
/// the [ReconciliationResult] describing what changed and re-registers the
/// refreshed `host -> stableId` bindings in the optional [DeviceIdentityRegistry]
/// (so brand secret stores and the transport resolver see the new host
/// immediately, in-session). The caller is responsible for persisting any
/// [ReconciliationResult.updatedSavedDevices] via the device repository so the
/// new host survives a cold start.
class DeviceReconciliationService {
  DeviceReconciliationService({this._identityRegistry});

  final DeviceIdentityRegistry? _identityRegistry;

  /// Reconciles [discovered] (ephemeral, freshly scanned) against [saved]
  /// (persisted) by stable id, with a conservative host/brand fallback for
  /// legacy IP-derived saved records.
  ///
  ///   * Devices on either side without a stable id are skipped by the stable
  ///     identity pass.
  ///   * When a match is found and the discovered host differs from the saved
  ///     host, the saved device is copied with the new host and included in
  ///     [ReconciliationResult.updatedSavedDevices].
  ///   * Every matched pair (regardless of whether the host changed) is
  ///     re-registered in the registry under the discovered host so the
  ///     transport resolver and brand secret stores address the current IP.
  ///   * A discovered device that carries a stable id but matches no saved
  ///     device is still registered (so a freshly paired device is addressable
  ///     by stable id without a round-trip through the repository).
  ///   * A legacy saved device is eligible for [LegacyDeviceRekey] only when
  ///     exactly one stable discovery and exactly one legacy saved device share
  ///     the same non-empty host and brand. If the IP changed, the match is
  ///     intentionally skipped because a host-only match cannot prove the
  ///     physical identity.
  ReconciliationResult reconcile({
    required List<TvDevice> discovered,
    required List<TvDevice> saved,
  }) {
    final savedByStableId = <String, TvDevice>{};
    for (final device in saved) {
      if (!device.hasStableId) continue;
      savedByStableId.putIfAbsent(device.id, () => device);
    }

    final updated = <TvDevice>[];
    final matches = <ReconciledPair>[];
    final legacyRekeys = <LegacyDeviceRekey>[];
    final stableDiscoveriesByHostAndBrand =
        <(String, TvBrand), List<TvDevice>>{};
    final legacySavedByHostAndBrand = <(String, TvBrand), List<TvDevice>>{};
    final stableSavedByHostAndBrand = <(String, TvBrand), List<TvDevice>>{};

    for (final candidate in discovered) {
      if (!candidate.hasStableId) continue;
      final host = _normalizeHost(candidate.resolvedHost);
      if (host.isEmpty) continue;
      stableDiscoveriesByHostAndBrand
          .putIfAbsent((host, candidate.brand), () => <TvDevice>[])
          .add(candidate);
    }
    for (final device in saved) {
      final host = _normalizeHost(device.resolvedHost);
      if (host.isEmpty) continue;
      final key = (host, device.brand);
      if (device.hasStableId) {
        stableSavedByHostAndBrand
            .putIfAbsent(key, () => <TvDevice>[])
            .add(device);
      } else {
        legacySavedByHostAndBrand
            .putIfAbsent(key, () => <TvDevice>[])
            .add(device);
      }
    }

    for (final candidate in discovered) {
      if (!candidate.hasStableId) continue;
      final stableId = candidate.id;

      final existing = savedByStableId[stableId];
      final discoveredHost = candidate.resolvedHost;
      _register(discoveredHost, stableId);

      if (existing == null) {
        continue;
      }
      matches.add(ReconciledPair(saved: existing, discovered: candidate));

      final savedHost = existing.resolvedHost;
      if (discoveredHost.isEmpty ||
          _normalizeHost(discoveredHost) == _normalizeHost(savedHost)) {
        continue;
      }
      updated.add(existing.copyWith(host: discoveredHost));
    }

    for (final entry in stableDiscoveriesByHostAndBrand.entries) {
      final discoveredAtHost = entry.value;
      final legacyAtHost = legacySavedByHostAndBrand[entry.key] ?? const [];
      final stableSavedAtHost =
          stableSavedByHostAndBrand[entry.key] ?? const [];
      if (discoveredAtHost.length != 1 ||
          legacyAtHost.length != 1 ||
          stableSavedAtHost.isNotEmpty) {
        continue;
      }
      final discoveredDevice = discoveredAtHost.single;
      final legacyDevice = legacyAtHost.single;
      legacyRekeys.add(
        LegacyDeviceRekey(
          legacy: legacyDevice,
          discovered: discoveredDevice,
          migrated: legacyDevice.copyWith(
            id: discoveredDevice.id,
            host: discoveredDevice.resolvedHost,
          ),
        ),
      );
    }

    return ReconciliationResult(
      updatedSavedDevices: updated,
      matches: matches,
      legacyRekeys: legacyRekeys,
    );
  }

  void _register(String host, String stableId) {
    final registry = _identityRegistry;
    if (registry == null || host.isEmpty) return;
    registry.register(host, stableId);
  }

  static String _normalizeHost(String host) => host.trim().toLowerCase();
}

/// Outcome of a reconciliation pass.
class ReconciliationResult {
  const ReconciliationResult({
    required this.updatedSavedDevices,
    required this.matches,
    required this.legacyRekeys,
  });

  /// Saved devices whose host changed and must be persisted so the new LAN
  /// address survives a cold start. Empty when nothing moved.
  final List<TvDevice> updatedSavedDevices;

  /// Every discovered ↔ saved pair matched by stable id, including ones whose
  /// host did not change. Useful for telemetry and for marking discovered
  /// devices as "previously paired" in the UI.
  final List<ReconciledPair> matches;

  /// Legacy saved devices that can be safely re-keyed by an exact host+brand
  /// match to one stable discovery.
  final List<LegacyDeviceRekey> legacyRekeys;
}

/// A single discovered ↔ saved match made by stable id.
class ReconciledPair {
  const ReconciledPair({required this.saved, required this.discovered});

  final TvDevice saved;
  final TvDevice discovered;
}

/// A conservative migration candidate from an IP-derived id to a stable id.
class LegacyDeviceRekey {
  const LegacyDeviceRekey({
    required this.legacy,
    required this.discovered,
    required this.migrated,
  });

  final TvDevice legacy;
  final TvDevice discovered;
  final TvDevice migrated;
}
