import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

/// Discovers TVs over local network via SSDP M-SEARCH.
///
/// This keeps MVP discovery lightweight and dependency-free while still
/// finding common UPnP/SSDP-advertised devices for Samsung/LG/Hisense.
class SsdpDeviceDiscoveryService implements DeviceDiscoveryService {
  SsdpDeviceDiscoveryService({
    this.timeout = const Duration(seconds: 3),
  });

  final Duration timeout;

  static const List<String> _searchTargets = <String>[
    'ssdp:all',
    'upnp:rootdevice',
    'urn:schemas-upnp-org:device:MediaRenderer:1',
  ];

  @override
  Future<List<TvDevice>> discoverDevices() async {
    RawDatagramSocket? socket;
    final candidatesByIp = <String, _DiscoveryCandidate>{};

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      final listener = socket.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final datagram = socket?.receive();
        if (datagram == null) {
          return;
        }
        final payload = utf8.decode(datagram.data, allowMalformed: true);
        final headers = _parseHeaders(payload);
        final brand = _inferBrand(headers);
        if (brand == null) {
          return;
        }
        final ip = _extractHostFromLocation(headers['location']) ??
            datagram.address.address;
        candidatesByIp[ip] = _DiscoveryCandidate(ip: ip, brand: brand);
      });

      for (final target in _searchTargets) {
        final message = _buildMSearch(target);
        socket.send(
          utf8.encode(message),
          InternetAddress('239.255.255.250'),
          1900,
        );
      }

      await Future<void>.delayed(timeout);
      await listener.cancel();
    } on SocketException {
      return const <TvDevice>[];
    } finally {
      socket?.close();
    }

    final devices = candidatesByIp.values
        .map(
          (candidate) => TvDevice(
            id: '${candidate.brand.name}-${candidate.ip}',
            displayName:
                '${_brandName(candidate.brand)} TV (${candidate.ip})',
            brand: candidate.brand,
            capabilities: _capabilitiesForBrand(candidate.brand),
          ),
        )
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return devices;
  }

  String _buildMSearch(String searchTarget) {
    return [
      'M-SEARCH * HTTP/1.1',
      'HOST: 239.255.255.250:1900',
      'MAN: "ssdp:discover"',
      'MX: 2',
      'ST: $searchTarget',
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

  TvBrand? _inferBrand(Map<String, String> headers) {
    final probe = [
      headers['server'] ?? '',
      headers['st'] ?? '',
      headers['usn'] ?? '',
      headers['location'] ?? '',
    ].join(' ');

    if (probe.contains('samsung') || probe.contains('tizen')) {
      return TvBrand.samsung;
    }
    if (probe.contains('lg') || probe.contains('webos')) {
      return TvBrand.lg;
    }
    if (probe.contains('hisense') || probe.contains('vidaa')) {
      return TvBrand.hisense;
    }
    return null;
  }

  Set<DeviceCapability> _capabilitiesForBrand(TvBrand brand) {
    if (brand == TvBrand.hisense) {
      return const {
        DeviceCapability.keyCommands,
        DeviceCapability.powerControl,
      };
    }
    return const {
      DeviceCapability.keyCommands,
      DeviceCapability.textInput,
      DeviceCapability.powerControl,
    };
  }

  String _brandName(TvBrand brand) {
    return switch (brand) {
      TvBrand.samsung => 'Samsung',
      TvBrand.lg => 'LG',
      TvBrand.hisense => 'Hisense',
    };
  }

  String? _extractHostFromLocation(String? locationHeader) {
    if (locationHeader == null || locationHeader.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(locationHeader);
    if (uri == null) {
      return null;
    }
    final host = uri.host.trim();
    if (host.isEmpty) {
      return null;
    }
    return host;
  }
}

class _DiscoveryCandidate {
  const _DiscoveryCandidate({
    required this.ip,
    required this.brand,
  });

  final String ip;
  final TvBrand brand;
}
