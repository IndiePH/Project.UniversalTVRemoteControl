import 'dart:io';

import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Discovers Android TV / Google TV devices via mDNS (_androidtvremote2._tcp).
class MdnsDeviceDiscoveryService implements DeviceDiscoveryService {
  MdnsDeviceDiscoveryService({this.timeout = const Duration(seconds: 5)});

  final Duration timeout;

  static const String _serviceType = '_androidtvremote2._tcp.local';

  @override
  Future<List<TvDevice>> discoverDevices() async {
    final multicastLock = FlutterMulticastLock();
    final bool acquired;
    if (Platform.isAndroid) {
      final alreadyHeld = await multicastLock.isMulticastLockHeld();
      acquired = !alreadyHeld;
      if (acquired) await multicastLock.acquireMulticastLock();
    } else {
      acquired = false;
    }
    try {
      return await _discoverDevicesCore();
    } finally {
      if (acquired) await multicastLock.releaseMulticastLock();
    }
  }

  Future<List<TvDevice>> _discoverDevicesCore() async {
    final client = MDnsClient();
    try {
      await client.start();

      // Two rounds of PTR discovery to handle dropped multicast packets.
      // The second round only fires if the first returns no results.
      final ptrMap = <String, PtrResourceRecord>{};
      for (var round = 0; round < 2; round++) {
        final ptrs = await client
            .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(_serviceType),
              timeout: timeout,
            )
            .toList();
        for (final ptr in ptrs) {
          ptrMap.putIfAbsent(ptr.domainName, () => ptr);
        }
        if (ptrMap.isNotEmpty) break;
      }

      final resolved = await Future.wait(
        ptrMap.values.map((ptr) => _resolveToDevice(client, ptr)),
      );

      final devicesByIp = <String, TvDevice>{};
      for (final device in resolved.nonNulls) {
        devicesByIp.putIfAbsent(device.id, () => device);
      }

      return devicesByIp.values.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
    } on SocketException {
      return const [];
    } finally {
      client.stop();
    }
  }

  Future<TvDevice?> _resolveToDevice(
    MDnsClient client,
    PtrResourceRecord ptr,
  ) async {
    SrvResourceRecord? srv;
    await for (final record in client.lookup<SrvResourceRecord>(
      ResourceRecordQuery.service(ptr.domainName),
      timeout: timeout,
    )) {
      srv = record;
      break;
    }
    if (srv == null) return null;

    await for (final ip in client.lookup<IPAddressResourceRecord>(
      ResourceRecordQuery.addressIPv4(srv.target),
      timeout: timeout,
    )) {
      final instanceName = _instanceName(ptr.domainName);
      return TvDevice(
        id: 'androidtv-${ip.address.address}',
        displayName: instanceName,
        brand: TvBrand.androidTv,
        capabilities: const TvCapabilities().capabilitiesFor(TvBrand.androidTv),
        host: ip.address.address,
      );
    }
    return null;
  }

  String _instanceName(String domainName) {
    const suffix = '._androidtvremote2._tcp.local';
    if (domainName.toLowerCase().endsWith(suffix)) {
      return domainName.substring(0, domainName.length - suffix.length);
    }
    return domainName;
  }
}
