import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_repository.dart';
import 'package:one_remote/src/features/remote_control/application/layout_repository.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/hisense/real_hisense_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/real_samsung_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/data/fake_device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/data/in_memory_device_repository.dart';
import 'package:one_remote/src/features/remote_control/data/shared_prefs_layout_repository.dart';
import 'package:one_remote/src/features/remote_control/data/ssdp_device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/remote_home_page.dart';
import 'package:one_remote/src/theme/app_theme.dart';

class OneRemoteApp extends StatelessWidget {
  const OneRemoteApp({super.key});

  static const bool _useFakeTransports = bool.fromEnvironment(
    'USE_FAKE_TRANSPORTS',
    defaultValue: false,
  );
  static const String _tvHostOverride = String.fromEnvironment('TV_HOST_OVERRIDE');

  @override
  Widget build(BuildContext context) {
    final DeviceRepository deviceRepository = InMemoryDeviceRepository();
    final DeviceDiscoveryService discoveryService = _useFakeTransports
        ? FakeDeviceDiscoveryService()
        : SsdpDeviceDiscoveryService();
    final LayoutRepository layoutRepository = SharedPrefsLayoutRepository();
    final RemoteCommandService commandService = BrandRoutedRemoteCommandService(
      adapters: [
        _buildSamsungAdapter(),
        LgAdapter(),
        _buildHisenseAdapter(),
      ],
    );

    return MaterialApp(
      title: 'OneRemote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: RemoteHomePage(
        commandService: commandService,
        deviceRepository: deviceRepository,
        discoveryService: discoveryService,
        layoutRepository: layoutRepository,
      ),
    );
  }

  SamsungAdapter _buildSamsungAdapter() {
    // Real transport is the default for APK/physical-TV testing.
    // Use one global fake toggle only for offline/lab runs:
    // --dart-define=USE_FAKE_TRANSPORTS=true
    if (_useFakeTransports) {
      return SamsungAdapter();
    }

    return SamsungAdapter(
      transportClient: RealSamsungTransportClient(
        hostResolver: _resolveSamsungHost,
      ),
    );
  }

  /// Default APK/runtime wiring uses real Hisense MQTT (VIDAA). This follows
  /// the same global fake switch used by Samsung for offline/test runs.
  HisenseAdapter _buildHisenseAdapter() {
    if (_useFakeTransports) {
      return HisenseAdapter();
    }
    return HisenseAdapter(
      transportClient: RealHisenseTransportClient(
        hostResolver: _resolveHisenseHost,
      ),
    );
  }

  String _resolveSamsungHost(String deviceId) {
    final explicitHost = _tvHostOverride.trim();
    if (explicitHost.isNotEmpty) {
      return explicitHost;
    }
    return _ipv4FromDeviceId(deviceId);
  }

  String _resolveHisenseHost(String deviceId) {
    final explicitHost = _tvHostOverride.trim();
    if (explicitHost.isNotEmpty) {
      return explicitHost;
    }
    return _ipv4FromDeviceId(deviceId);
  }

  /// Device IDs from discovery/manual pairing are expected as `<brand>-<ip>`.
  static String _ipv4FromDeviceId(String deviceId) {
    final ipv4Regex = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');
    final match = ipv4Regex.firstMatch(deviceId);
    if (match == null) {
      return '';
    }
    return match.group(1) ?? '';
  }
}
