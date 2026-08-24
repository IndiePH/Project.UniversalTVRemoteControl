import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/app/diagnostics/diagnostics_recording_device_discovery_service.dart';
import 'package:one_remote/app/diagnostics/diagnostics_recording_remote_command_service.dart';
import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/remote_control/application/application.dart';
import 'package:one_remote/remote_control/data/data.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_certificate_store.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_handshake_tracer.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_tcp_transport_client.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_host_resolver.dart';
import 'package:one_remote/remote_control/data/persistence/secure_device_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/debug/fake_android_tv_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_hisense_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_roku_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_tcl_legacy_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_pairing_auth_store.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_mqtt_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_pairing_token_store.dart';
import 'package:one_remote/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_pairing_key_store.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_websocket_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_websocket_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/sony_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/roku_http_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/roku_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_legacy_tcp_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_legacy_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_lg_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_samsung_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl_legacy_wifi_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/tcl_roku_adapter.dart';

void _configureShared(GetIt sl) {
  sl.registerSingleton<AppDiagnosticsRecorder>(AppDiagnosticsRecorder());
  sl.registerSingleton<DeviceIdentityRegistry>(DeviceIdentityRegistry());
  sl.registerSingleton<DeviceRepository>(
    SharedPrefsDeviceRepository(identityRegistry: sl<DeviceIdentityRegistry>()),
  );
  sl.registerSingleton<LayoutRepository>(SharedPrefsLayoutRepository());
  sl.registerSingleton<PrePairingStepsRegistry>(
    DefaultPrePairingStepsRegistry(localizedStrings: sl<LocalizedStrings>()),
  );
  sl.registerSingleton<PairingProgressHintRegistry>(
    DefaultPairingProgressHintRegistry(
      localizedStrings: sl<LocalizedStrings>(),
    ),
  );
  sl.registerSingleton<VariantResolutionRegistry>(
    const DefaultVariantResolutionRegistry(),
  );
}

final class RemoteControlDiConfig implements IDiConfig {
  const RemoteControlDiConfig();

  static const String _tvHostOverride = String.fromEnvironment(
    'TV_HOST_OVERRIDE',
  );
  static const bool _legacyTclEnabled = bool.fromEnvironment(
    'TCL_LEGACY_WIFI_ENABLED',
    defaultValue: false,
  );

  @override
  void configure(GetIt sl, AppEnvironment env) {
    _configureShared(sl);
    final resolveHost = _buildHostResolver(sl<DeviceIdentityRegistry>());
    sl.registerSingleton<LgPairingKeyStore>(
      LgPairingKeyStore(
        identityRegistry: sl<DeviceIdentityRegistry>(),
        devicePersistence: SecureDeviceScopedSecretPersistence(
          keyPrefix: 'lg_client_key_dev_',
        ),
      ),
    );
    sl.registerSingleton<SamsungPairingTokenStore>(
      SamsungPairingTokenStore(
        identityRegistry: sl<DeviceIdentityRegistry>(),
        devicePersistence: SecureDeviceScopedSecretPersistence(
          keyPrefix: 'samsung_remote_token_dev_',
        ),
      ),
    );
    sl.registerSingleton<SamsungTransportClient>(
      SamsungWebSocketTransportClient(
        hostResolver: resolveHost,
        pairingTokenStore: sl<SamsungPairingTokenStore>(),
      ),
    );
    sl.registerSingleton<LgTransportClient>(
      LgWebSocketTransportClient(
        hostResolver: resolveHost,
        keyStore: sl<LgPairingKeyStore>(),
      ),
    );
    sl.registerSingleton<HisensePairingAuthStore>(
      HisensePairingAuthStore(
        identityRegistry: sl<DeviceIdentityRegistry>(),
        devicePersistence: SecureDeviceScopedSecretPersistence(
          keyPrefix: 'hisense_mqtt_paired_dev_',
        ),
      ),
    );
    sl.registerSingleton<HisenseTransportClient>(
      HisenseMqttTransportClient(
        hostResolver: resolveHost,
        pairingAuthStore: sl<HisensePairingAuthStore>(),
      ),
    );
    sl.registerSingleton<AndroidTvCertificateStore>(
      AndroidTvCertificateStore(),
    );
    final androidTvTransport = AndroidTvTcpTransportClient(
      hostResolver: resolveHost,
      certStore: sl<AndroidTvCertificateStore>(),
      tracer: env == AppEnvironment.debug ? AndroidTvHandshakeTracer() : null,
    );
    sl.registerSingleton<AndroidTvTransportClient>(androidTvTransport);
    sl.registerSingleton<DeviceDiscoveryService>(
      DiagnosticsRecordingDeviceDiscoveryService(
        delegate: CompositeDeviceDiscoveryService(
          services: [
            SsdpDeviceDiscoveryService(),
            MdnsDeviceDiscoveryService(),
            RokuSsdpDiscoveryService(),
          ],
          androidTvIdentityResolver: androidTvTransport,
        ),
        recorder: sl<AppDiagnosticsRecorder>(),
      ),
    );
    sl.registerSingleton<RokuTransportClient>(
      RokuHttpTransportClient(hostResolver: resolveHost),
    );
    if (_legacyTclEnabled) {
      sl.registerSingleton<TclLegacyTransportClient>(
        TclLegacyTcpTransportClient(hostResolver: resolveHost),
      );
    } else {
      sl.registerSingleton<TclLegacyTransportClient>(
        FakeTclLegacyTransportClient(),
      );
    }
    final adapters = [
      SamsungAdapter(transportClient: sl<SamsungTransportClient>()),
      LgAdapter(transportClient: sl<LgTransportClient>()),
      HisenseAdapter(transportClient: sl<HisenseTransportClient>()),
      AndroidTvAdapter(transportClient: sl<AndroidTvTransportClient>()),
      SonyAdapter(transportClient: sl<AndroidTvTransportClient>()),
      TclRokuAdapter(transportClient: sl<RokuTransportClient>()),
      TclLegacyWifiAdapter(transportClient: sl<TclLegacyTransportClient>()),
    ];
    final commandService = BrandRoutedRemoteCommandService(
      adapters: adapters,
      variantRegistry: sl<VariantResolutionRegistry>(),
      localizedStrings: sl<LocalizedStrings>(),
      identityRegistry: sl<DeviceIdentityRegistry>(),
    );
    sl.registerSingleton<TransportLogReaderProvider>(commandService);
    sl.registerSingleton<RemoteCommandService>(
      DiagnosticsRecordingRemoteCommandService(
        delegate: commandService,
        recorder: sl<AppDiagnosticsRecorder>(),
      ),
    );
    sl.registerSingleton<TvConnectionStateService>(
      MultiplexedTvConnectionStateService(
        commandService: sl<RemoteCommandService>(),
      ),
    );
    sl.registerSingleton<TvReachabilityService>(
      AdapterTvReachabilityService(adapters: adapters),
    );
  }

  /// Builds a transport host resolver that prefers the identity registry's
  /// current host for a stable id, falling back to the legacy IPv4-in-id regex
  /// for IP-derived (legacy) device ids.
  static String Function(String) _buildHostResolver(
    DeviceIdentityRegistry identityRegistry,
  ) {
    return (String deviceId) {
      final explicitHost = _tvHostOverride.trim();
      if (explicitHost.isNotEmpty) return explicitHost;
      final registryHost = identityRegistry.hostForStableId(deviceId);
      if (registryHost != null && registryHost.isNotEmpty) {
        return registryHost;
      }
      return LegacyHostResolver.hostFromDeviceId(deviceId);
    };
  }
}

final class DebugRemoteControlDiConfig implements IDiConfig {
  const DebugRemoteControlDiConfig();

  @override
  void configure(GetIt sl, AppEnvironment env) {
    _configureShared(sl);
    // Debug config keeps command transports fake-able via DI. Discovery mode can
    // still be switched at runtime from the debug settings flow (pairing path).
    sl.registerSingleton<DeviceDiscoveryService>(
      DiagnosticsRecordingDeviceDiscoveryService(
        delegate: CompositeDeviceDiscoveryService(
          services: [
            SsdpDeviceDiscoveryService(),
            MdnsDeviceDiscoveryService(),
            RokuSsdpDiscoveryService(),
          ],
        ),
        recorder: sl<AppDiagnosticsRecorder>(),
      ),
    );
    sl.registerSingleton<SamsungTransportClient>(FakeSamsungTransportClient());
    sl.registerSingleton<LgTransportClient>(FakeLgTransportClient());
    sl.registerSingleton<HisenseTransportClient>(FakeHisenseTransportClient());
    sl.registerSingleton<AndroidTvTransportClient>(
      FakeAndroidTvTransportClient(),
    );
    sl.registerSingleton<RokuTransportClient>(FakeRokuTransportClient());
    sl.registerSingleton<TclLegacyTransportClient>(
      FakeTclLegacyTransportClient(),
    );
    final adapters = [
      SamsungAdapter(transportClient: sl<SamsungTransportClient>()),
      LgAdapter(transportClient: sl<LgTransportClient>()),
      HisenseAdapter(transportClient: sl<HisenseTransportClient>()),
      AndroidTvAdapter(transportClient: sl<AndroidTvTransportClient>()),
      SonyAdapter(transportClient: sl<AndroidTvTransportClient>()),
      TclRokuAdapter(transportClient: sl<RokuTransportClient>()),
      TclLegacyWifiAdapter(transportClient: sl<TclLegacyTransportClient>()),
    ];
    final commandService = BrandRoutedRemoteCommandService(
      adapters: adapters,
      variantRegistry: sl<VariantResolutionRegistry>(),
      localizedStrings: sl<LocalizedStrings>(),
      identityRegistry: sl<DeviceIdentityRegistry>(),
    );
    sl.registerSingleton<TransportLogReaderProvider>(commandService);
    sl.registerSingleton<RemoteCommandService>(
      DiagnosticsRecordingRemoteCommandService(
        delegate: commandService,
        recorder: sl<AppDiagnosticsRecorder>(),
      ),
    );
    sl.registerSingleton<TvConnectionStateService>(
      MultiplexedTvConnectionStateService(
        commandService: sl<RemoteCommandService>(),
      ),
    );
    sl.registerSingleton<TvReachabilityService>(
      AdapterTvReachabilityService(adapters: adapters),
    );
  }
}
