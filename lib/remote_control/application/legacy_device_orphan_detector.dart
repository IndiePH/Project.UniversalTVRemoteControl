import 'package:one_remote/remote_control/application/device_last_seen_repository.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Detects legacy IP-keyed saved devices that have not been seen recently.
///
/// Detection is deliberately separate from deletion. Callers must present the
/// returned devices for explicit user confirmation before removing anything.
final class LegacyDeviceOrphanDetector {
  const LegacyDeviceOrphanDetector._();

  static const Duration staleGracePeriod = Duration(days: 30);

  /// Records a successful discovery observation and returns stale, non-active
  /// legacy devices.
  ///
  /// A legacy device is considered seen when exactly one discovered device has
  /// the same brand and resolved host. This allows a legacy IP-keyed record to
  /// keep its tracking timestamp even when discovery has started reporting a
  /// stable id for the same TV.
  static Future<List<TvDevice>> updateAndFindCandidates({
    required List<TvDevice> savedDevices,
    required List<TvDevice> discoveredDevices,
    required String? activeDeviceId,
    required DeviceLastSeenRepository repository,
    DateTime? now,
  }) async {
    final observedAt = now ?? DateTime.now();
    final discoveredByHostAndBrand = <String, List<TvDevice>>{};
    for (final discovered in discoveredDevices) {
      final key = _hostAndBrandKey(discovered);
      if (key == null) continue;
      discoveredByHostAndBrand
          .putIfAbsent(key, () => <TvDevice>[])
          .add(discovered);
    }

    final candidates = <TvDevice>[];
    for (final saved in savedDevices) {
      if (saved.hasStableId || saved.id == activeDeviceId) continue;

      final key = _hostAndBrandKey(saved);
      final observedMatches = key == null
          ? const <TvDevice>[]
          : discoveredByHostAndBrand[key] ?? const <TvDevice>[];
      if (observedMatches.length == 1) {
        await repository.setLastSeenAt(
          deviceId: saved.id,
          timestamp: observedAt,
        );
        continue;
      }

      final lastSeenAt = await repository.getLastSeenAt(saved.id);
      if (lastSeenAt == null) {
        // Start the grace period on the first scan after this feature ships.
        // This avoids retroactively deleting a device based on unknown history.
        await repository.setLastSeenAt(
          deviceId: saved.id,
          timestamp: observedAt,
        );
        continue;
      }

      if (observedAt.difference(lastSeenAt) >= staleGracePeriod) {
        candidates.add(saved);
      }
    }
    return candidates;
  }

  static String? _hostAndBrandKey(TvDevice device) {
    final host = device.resolvedHost.trim().toLowerCase();
    if (host.isEmpty) return null;
    return '${device.brand.name}|$host';
  }
}
