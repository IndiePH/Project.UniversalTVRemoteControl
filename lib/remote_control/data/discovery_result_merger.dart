import 'package:one_remote/remote_control/application/discovered_device_support.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Merges parallel discovery results, preferring the strongest brand ID per IP.
final class DiscoveryResultMerger {
  const DiscoveryResultMerger._();

  static final _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');

  static List<TvDevice> mergeByHost(List<TvDevice> devices) {
    final byIp = <String, TvDevice>{};
    for (final device in devices) {
      final ip = _ipv4FromDeviceId(device.id);
      if (ip == null) {
        byIp.putIfAbsent(device.id, () => device);
        continue;
      }
      final existing = byIp[ip];
      if (existing == null ||
          DiscoveredDeviceSupport.brandIdentificationPriority(device.brand) <
              DiscoveredDeviceSupport.brandIdentificationPriority(
                existing.brand,
              )) {
        byIp[ip] = device;
      }
    }
    final merged = byIp.values.toList()
      ..sort(DiscoveredDeviceSupport.compareForDiscoveryList);
    return merged;
  }

  static String? _ipv4FromDeviceId(String deviceId) {
    return _ipv4.firstMatch(deviceId)?.group(1);
  }
}
