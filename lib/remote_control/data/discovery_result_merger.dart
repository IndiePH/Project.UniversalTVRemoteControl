import 'package:one_remote/remote_control/application/discovered_device_support.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Merges parallel discovery results, preferring the strongest brand ID per IP.
final class DiscoveryResultMerger {
  const DiscoveryResultMerger._();

  static List<TvDevice> mergeByHost(List<TvDevice> devices) {
    final byIp = <String, TvDevice>{};
    for (final device in devices) {
      final ip = device.resolvedHost;
      final key = ip.isEmpty ? device.id : ip;
      final existing = byIp[key];
      if (existing == null ||
          DiscoveredDeviceSupport.brandIdentificationPriority(device.brand) <
              DiscoveredDeviceSupport.brandIdentificationPriority(
                existing.brand,
              )) {
        byIp[key] = device;
      }
    }
    final merged = byIp.values.toList()
      ..sort(DiscoveredDeviceSupport.compareForDiscoveryList);
    return merged;
  }
}
