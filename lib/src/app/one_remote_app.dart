import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_repository.dart';
import 'package:one_remote/src/features/remote_control/application/layout_repository.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/real_samsung_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/data/in_memory_device_repository.dart';
import 'package:one_remote/src/features/remote_control/data/shared_prefs_layout_repository.dart';
import 'package:one_remote/src/features/remote_control/data/ssdp_device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/remote_home_page.dart';
import 'package:one_remote/src/theme/app_theme.dart';

class OneRemoteApp extends StatelessWidget {
  const OneRemoteApp({super.key});

  static const bool _useRealSamsungTransport = bool.fromEnvironment(
    'USE_REAL_SAMSUNG_TRANSPORT',
    defaultValue: true,
  );
  static const String _samsungTvHost = String.fromEnvironment('SAMSUNG_TV_HOST');

  @override
  Widget build(BuildContext context) {
    final DeviceRepository deviceRepository = InMemoryDeviceRepository();
    final DeviceDiscoveryService discoveryService = SsdpDeviceDiscoveryService();
    final LayoutRepository layoutRepository = SharedPrefsLayoutRepository();
    final RemoteCommandService commandService = BrandRoutedRemoteCommandService(
      adapters: [
        _buildSamsungAdapter(),
        LgAdapter(),
        HisenseAdapter(),
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
    if (!_useRealSamsungTransport) {
      return SamsungAdapter();
    }

    return SamsungAdapter(
      transportClient: RealSamsungTransportClient(
        hostResolver: _resolveSamsungHost,
      ),
    );
  }

  String _resolveSamsungHost(String deviceId) {
    final explicitHost = _samsungTvHost.trim();
    if (explicitHost.isNotEmpty) {
      return explicitHost;
    }

    // Device IDs from discovery/manual pairing are expected as "<brand>-<ip>".
    final ipv4Regex = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');
    final match = ipv4Regex.firstMatch(deviceId);
    if (match == null) {
      return '';
    }
    return match.group(1) ?? '';
  }
}
