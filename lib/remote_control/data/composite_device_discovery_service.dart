import 'dart:io';

import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Runs multiple [DeviceDiscoveryService] implementations in parallel and
/// merges their results, deduplicating by device ID.
class CompositeDeviceDiscoveryService implements DeviceDiscoveryService {
  const CompositeDeviceDiscoveryService({required this.services});

  final List<DeviceDiscoveryService> services;

  @override
  Future<List<TvDevice>> discoverDevices() async {
    // On Android the Wi-Fi multicast lock must be held for the entire scan
    // window. Acquiring it here prevents any individual service from releasing
    // it early while sibling services are still listening.
    final multicastLock = FlutterMulticastLock();
    if (Platform.isAndroid) {
      await multicastLock.acquireMulticastLock();
    }
    try {
      final results = await Future.wait(
        services.map((s) async {
          try {
            return await s.discoverDevices();
          } catch (_) {
            return const <TvDevice>[];
          }
        }),
      );

      final seen = <String>{};
      return results
          .expand((list) => list)
          .where((device) => seen.add(device.id))
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
    } finally {
      if (Platform.isAndroid) {
        try {
          await multicastLock.releaseMulticastLock();
        } catch (_) {}
      }
    }
  }
}
