import 'dart:io';

import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import 'package:one_remote/remote_control/application/android_tv_stable_identity_resolver.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/data/discovery_result_merger.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Runs multiple [DeviceDiscoveryService] implementations in parallel and
/// merges their results, deduplicating by host IP and brand priority.
class CompositeDeviceDiscoveryService implements DeviceDiscoveryService {
  const CompositeDeviceDiscoveryService({
    required this.services,
    this.androidTvIdentityResolver,
  });

  final List<DeviceDiscoveryService> services;
  final AndroidTvStableIdentityResolver? androidTvIdentityResolver;

  @override
  Future<List<TvDevice>> discoverDevices() async {
    // On Android the Wi-Fi multicast lock must be held until discoverDevices
    // fully completes, including Android TV identity enrichment after merge.
    // Await every Future in this try so finally does not release the lock
    // while enrichment (or sibling scans) is still running.
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

      final merged = DiscoveryResultMerger.mergeByHost(
        results.expand((list) => list).toList(),
      );
      return await Future.wait(merged.map(_enrichAndroidTvIdentity));
    } finally {
      if (Platform.isAndroid) {
        try {
          await multicastLock.releaseMulticastLock();
        } catch (_) {}
      }
    }
  }

  Future<TvDevice> _enrichAndroidTvIdentity(TvDevice device) async {
    final resolver = androidTvIdentityResolver;
    if (device.brand != TvBrand.androidTv || resolver == null) {
      return device;
    }

    final host = device.resolvedHost.trim();
    if (host.isEmpty) return device;

    try {
      final stableId = await resolver.discoverStableIdAtHost(host);
      if (stableId == null || stableId.trim().isEmpty) return device;
      return device.copyWith(id: stableId.trim());
    } catch (_) {
      // Identity enrichment is best-effort. The IP-derived discovery result
      // remains available when the TV cannot be probed during this scan.
      return device;
    }
  }
}
