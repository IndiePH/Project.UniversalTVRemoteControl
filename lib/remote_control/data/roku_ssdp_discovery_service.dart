import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/data/discovery_variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/discovery_source.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

class RokuSsdpDiscoveryService implements DeviceDiscoveryService {
  RokuSsdpDiscoveryService({
    required this.discoveryVariantRegistry,
    this.timeout = const Duration(seconds: 3),
  });

  final Duration timeout;
  final DiscoveryVariantResolutionRegistry discoveryVariantRegistry;

  @override
  Future<List<TvDevice>> discoverDevices() async {
    final multicastLock = FlutterMulticastLock();
    final bool acquired;
    if (Platform.isAndroid) {
      final alreadyHeld = await multicastLock.isMulticastLockHeld();
      acquired = !alreadyHeld;
      if (acquired) {
        await multicastLock.acquireMulticastLock();
      }
    } else {
      acquired = false;
    }
    try {
      return await _discoverDevicesCore();
    } finally {
      if (acquired) {
        await multicastLock.releaseMulticastLock();
      }
    }
  }

  Future<List<TvDevice>> _discoverDevicesCore() async {
    RawDatagramSocket? socket;
    final seenIps = <String>{};
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      final devices = <TvDevice>[];
      final listener = socket.listen((event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final datagram = socket?.receive();
        if (datagram == null) {
          return;
        }
        final payload = utf8.decode(datagram.data, allowMalformed: true);
        final headers = _parseHeaders(payload);
        if (!_looksLikeRoku(headers)) {
          return;
        }
        final ip =
            _extractHostFromLocation(headers['location']) ??
            datagram.address.address;
        if (!seenIps.add(ip)) {
          return;
        }
        devices.add(
          TvDevice(
            id: 'roku-$ip',
            displayName: 'Roku TV ($ip)',
            brand: TvBrand.roku,
            protocolVariant: discoveryVariantRegistry.resolveFromDiscovery(
              brand: TvBrand.roku,
              source: DiscoverySource.roku,
            ),
            capabilities: const TvCapabilities().capabilitiesFor(TvBrand.roku),
            host: ip,
          ),
        );
      });

      socket.send(
        utf8.encode(_buildMSearch()),
        InternetAddress('239.255.255.250'),
        1900,
      );

      await Future<void>.delayed(timeout);
      await listener.cancel();
      devices.sort((a, b) => a.displayName.compareTo(b.displayName));
      return devices;
    } on SocketException {
      return const <TvDevice>[];
    } finally {
      socket?.close();
    }
  }

  String _buildMSearch() {
    return [
      'M-SEARCH * HTTP/1.1',
      'HOST: 239.255.255.250:1900',
      'MAN: "ssdp:discover"',
      'MX: 2',
      'ST: roku:ecp',
      '',
      '',
    ].join('\r\n');
  }

  Map<String, String> _parseHeaders(String payload) {
    final headers = <String, String>{};
    final lines = payload.split('\r\n');
    for (final line in lines) {
      final separator = line.indexOf(':');
      if (separator <= 0) {
        continue;
      }
      final key = line.substring(0, separator).trim().toLowerCase();
      final value = line.substring(separator + 1).trim().toLowerCase();
      headers[key] = value;
    }
    return headers;
  }

  bool _looksLikeRoku(Map<String, String> headers) {
    final probe = [
      headers['server'] ?? '',
      headers['st'] ?? '',
      headers['usn'] ?? '',
      headers['location'] ?? '',
    ].join(' ');
    return probe.contains('roku');
  }

  String? _extractHostFromLocation(String? locationHeader) {
    if (locationHeader == null || locationHeader.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(locationHeader);
    if (uri == null) {
      return null;
    }
    return uri.host.trim().isEmpty ? null : uri.host.trim();
  }
}
