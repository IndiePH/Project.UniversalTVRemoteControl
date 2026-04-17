import 'package:flutter/material.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/application/device_discovery_service.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/application/device_repository.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/application/layout_repository.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/application/remote_command_service.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/adapters/hisense_adapter.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/adapters/lg_adapter.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/adapters/samsung_adapter.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/adapters/samsung/real_samsung_transport_client.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/fake_device_discovery_service.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/in_memory_device_repository.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/shared_prefs_layout_repository.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/presentation/pages/remote_home_page.dart';
import 'package:universal_tv_remove_control/src/theme/app_theme.dart';

class RemoteOneApp extends StatelessWidget {
  const RemoteOneApp({super.key});

  static const bool _useRealSamsungTransport = bool.fromEnvironment(
    'USE_REAL_SAMSUNG_TRANSPORT',
    defaultValue: false,
  );
  static const String _samsungTvHost = String.fromEnvironment('SAMSUNG_TV_HOST');

  @override
  Widget build(BuildContext context) {
    final DeviceRepository deviceRepository = InMemoryDeviceRepository();
    final DeviceDiscoveryService discoveryService = FakeDeviceDiscoveryService();
    final LayoutRepository layoutRepository = SharedPrefsLayoutRepository();
    final RemoteCommandService commandService = BrandRoutedRemoteCommandService(
      adapters: [
        _buildSamsungAdapter(),
        LgAdapter(),
        HisenseAdapter(),
      ],
    );

    return MaterialApp(
      title: 'RemoteOne',
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

    if (_samsungTvHost.trim().isEmpty) {
      debugPrint(
        'USE_REAL_SAMSUNG_TRANSPORT is true but SAMSUNG_TV_HOST is empty. '
        'Falling back to fake Samsung transport.',
      );
      return SamsungAdapter();
    }

    return SamsungAdapter(
      transportClient: RealSamsungTransportClient(
        hostResolver: (_) => _samsungTvHost,
      ),
    );
  }
}
