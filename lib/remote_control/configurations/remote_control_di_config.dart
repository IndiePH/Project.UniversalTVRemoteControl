import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/fake_hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/real_hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_pairing_key_store.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_websocket_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_log_reader.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_websocket_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/remote_control/data/fake_device_discovery_service.dart';
import 'package:one_remote/remote_control/data/shared_prefs_device_repository.dart';
import 'package:one_remote/remote_control/data/shared_prefs_layout_repository.dart';
import 'package:one_remote/remote_control/data/ssdp_device_discovery_service.dart';
import 'package:one_remote/remote_control/debug/fake_lg_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_samsung_transport_client.dart';

final class RemoteControlDiConfig implements IDiConfig {
  const RemoteControlDiConfig();

  static const String _tvHostOverride = String.fromEnvironment('TV_HOST_OVERRIDE');

  @override
  void configure(GetIt sl, AppEnvironment env) {
    final deviceRepository = SharedPrefsDeviceRepository();
    sl.registerSingleton<DeviceRepository>(deviceRepository);
    sl.registerSingleton<LayoutRepository>(SharedPrefsLayoutRepository());
    sl.registerSingleton<TransportLogReader>(const SamsungTransportLogReader());

    final useFake = env == AppEnvironment.debug;

    sl.registerSingleton<DeviceDiscoveryService>(
      useFake ? FakeDeviceDiscoveryService() : SsdpDeviceDiscoveryService(),
    );

    sl.registerSingleton<RemoteCommandService>(
      BrandRoutedRemoteCommandService(
        adapters: [
          SamsungAdapter(
            transportClient: useFake
                ? FakeSamsungTransportClient()
                : SamsungWebSocketTransportClient(hostResolver: _resolveHost),
          ),
          LgAdapter(
            transportClient: useFake
                ? FakeLgTransportClient()
                : LgWebSocketTransportClient(
                    hostResolver: _resolveHost,
                    keyStore: LgPairingKeyStore(),
                  ),
            onSystemInfo: (deviceId, info) {
              unawaited(deviceRepository.saveDeviceSystemInfo(deviceId, info));
            },
          ),
          HisenseAdapter(
            transportClient: useFake
                ? FakeHisenseTransportClient()
                : RealHisenseTransportClient(hostResolver: _resolveHost),
          ),
        ],
      ),
    );
  }

  static String _resolveHost(String deviceId) {
    final explicitHost = _tvHostOverride.trim();
    if (explicitHost.isNotEmpty) return explicitHost;
    return _ipv4FromDeviceId(deviceId);
  }

  static String _ipv4FromDeviceId(String deviceId) {
    final ipv4Regex = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');
    final match = ipv4Regex.firstMatch(deviceId);
    if (match == null) return '';
    return match.group(1) ?? '';
  }
}
