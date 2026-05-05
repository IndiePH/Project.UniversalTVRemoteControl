import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Runs multiple [DeviceDiscoveryService] implementations in parallel and
/// merges their results, deduplicating by device ID.
class CompositeDeviceDiscoveryService implements DeviceDiscoveryService {
  const CompositeDeviceDiscoveryService({required this.services});

  final List<DeviceDiscoveryService> services;

  @override
  Future<List<TvDevice>> discoverDevices() async {
    final results = await Future.wait(
      services.map((s) => s.discoverDevices()),
    );

    final seen = <String>{};
    return results
        .expand((list) => list)
        .where((device) => seen.add(device.id))
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }
}
