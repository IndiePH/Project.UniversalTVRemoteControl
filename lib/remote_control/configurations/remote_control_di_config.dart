import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/transport_log_reader_provider.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/tv_model_capability_registry.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/fake_hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/real_hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_pairing_key_store.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_websocket_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_websocket_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/remote_control/data/fake_device_discovery_service.dart';
import 'package:one_remote/remote_control/data/shared_prefs_device_repository.dart';
import 'package:one_remote/remote_control/data/shared_prefs_layout_repository.dart';
import 'package:one_remote/remote_control/data/ssdp_device_discovery_service.dart';
import 'package:one_remote/remote_control/debug/fake_lg_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_samsung_transport_client.dart';

void _configureShared(GetIt sl) {
  sl.registerSingleton<DeviceRepository>(SharedPrefsDeviceRepository());
  sl.registerSingleton<LayoutRepository>(SharedPrefsLayoutRepository());
  sl.registerSingleton<PrePairingStepsRegistry>(
    const DefaultPrePairingStepsRegistry(),
  );
  sl.registerSingleton<PairingProgressHintRegistry>(
    const DefaultPairingProgressHintRegistry(),
  );
  sl.registerSingleton<VariantResolutionRegistry>(
    const DefaultVariantResolutionRegistry(),
  );
  sl.registerSingleton<TvModelCapabilityRegistry>(
    const DefaultTvModelCapabilityRegistry(),
  );
}

final class RemoteControlDiConfig implements IDiConfig {
  const RemoteControlDiConfig();

  static const String _tvHostOverride = String.fromEnvironment('TV_HOST_OVERRIDE');

  @override
  void configure(GetIt sl, AppEnvironment env) {
    _configureShared(sl);
    sl.registerSingleton<DeviceDiscoveryService>(SsdpDeviceDiscoveryService());
    sl.registerSingleton<LgPairingKeyStore>(LgPairingKeyStore());
    sl.registerSingleton<SamsungTransportClient>(
      SamsungWebSocketTransportClient(hostResolver: _resolveHost),
    );
    sl.registerSingleton<LgTransportClient>(
      LgWebSocketTransportClient(
        hostResolver: _resolveHost,
        keyStore: sl<LgPairingKeyStore>(),
      ),
    );
    sl.registerSingleton<HisenseTransportClient>(
      RealHisenseTransportClient(hostResolver: _resolveHost),
    );
    final commandService = BrandRoutedRemoteCommandService(
      adapters: [
        SamsungAdapter(transportClient: sl<SamsungTransportClient>()),
        LgAdapter(transportClient: sl<LgTransportClient>()),
        HisenseAdapter(transportClient: sl<HisenseTransportClient>()),
      ],
      variantRegistry: sl<VariantResolutionRegistry>(),
      capabilityRegistry: sl<TvModelCapabilityRegistry>(),
    );
    sl.registerSingleton<RemoteCommandService>(commandService);
    sl.registerSingleton<TransportLogReaderProvider>(commandService);
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

final class DebugRemoteControlDiConfig implements IDiConfig {
  const DebugRemoteControlDiConfig();

  @override
  void configure(GetIt sl, AppEnvironment env) {
    _configureShared(sl);
    sl.registerSingleton<DeviceDiscoveryService>(FakeDeviceDiscoveryService());
    sl.registerSingleton<SamsungTransportClient>(FakeSamsungTransportClient());
    sl.registerSingleton<LgTransportClient>(FakeLgTransportClient());
    sl.registerSingleton<HisenseTransportClient>(FakeHisenseTransportClient());
    final commandService = BrandRoutedRemoteCommandService(
      adapters: [
        SamsungAdapter(transportClient: sl<SamsungTransportClient>()),
        LgAdapter(transportClient: sl<LgTransportClient>()),
        HisenseAdapter(transportClient: sl<HisenseTransportClient>()),
      ],
      variantRegistry: sl<VariantResolutionRegistry>(),
      capabilityRegistry: sl<TvModelCapabilityRegistry>(),
    );
    sl.registerSingleton<RemoteCommandService>(commandService);
    sl.registerSingleton<TransportLogReaderProvider>(commandService);
  }
}
