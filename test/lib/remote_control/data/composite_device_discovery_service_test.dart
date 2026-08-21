import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/android_tv_stable_identity_resolver.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/data/composite_device_discovery_service.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  test(
    'enriches Android TV discovery with a known certificate identity',
    () async {
      final resolver = _FakeAndroidTvIdentityResolver(
        stableIdByHost: {'192.168.1.20': 'androidtv-certificate-hash'},
      );
      final service = CompositeDeviceDiscoveryService(
        services: [
          _StaticDiscoveryService([
            const TvDevice(
              id: 'androidtv-192.168.1.20',
              displayName: 'Living Room TV',
              brand: TvBrand.androidTv,
              capabilities: {DeviceCapability.keyCommands},
              host: '192.168.1.20',
            ),
          ]),
        ],
        androidTvIdentityResolver: resolver,
      );

      final devices = await service.discoverDevices();

      expect(devices.single.id, 'androidtv-certificate-hash');
      expect(devices.single.resolvedHost, '192.168.1.20');
      expect(resolver.probedHosts, ['192.168.1.20']);
    },
  );

  test(
    'keeps the IP-derived identity when certificate proof is unavailable',
    () async {
      final service = CompositeDeviceDiscoveryService(
        services: [
          _StaticDiscoveryService([
            const TvDevice(
              id: 'androidtv-192.168.1.21',
              displayName: 'Bedroom TV',
              brand: TvBrand.androidTv,
              capabilities: {DeviceCapability.keyCommands},
              host: '192.168.1.21',
            ),
          ]),
        ],
        androidTvIdentityResolver: _FakeAndroidTvIdentityResolver(),
      );

      final devices = await service.discoverDevices();

      expect(devices.single.id, 'androidtv-192.168.1.21');
    },
  );
}

class _StaticDiscoveryService implements DeviceDiscoveryService {
  _StaticDiscoveryService(this.devices);

  final List<TvDevice> devices;

  @override
  Future<List<TvDevice>> discoverDevices() async => devices;
}

class _FakeAndroidTvIdentityResolver
    implements AndroidTvStableIdentityResolver {
  _FakeAndroidTvIdentityResolver({this.stableIdByHost = const {}});

  final Map<String, String> stableIdByHost;
  final List<String> probedHosts = [];

  @override
  Future<String?> discoverStableIdAtHost(String host) async {
    probedHosts.add(host);
    return stableIdByHost[host];
  }
}
