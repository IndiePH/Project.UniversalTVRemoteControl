import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/presentation/pages/remote_home_page.dart';
import 'package:one_remote/theme/app_theme.dart';

class OneRemoteApp extends StatelessWidget {
  const OneRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final sl = GetIt.instance;
    return MaterialApp(
      title: 'OneRemote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: RemoteHomePage(
        commandService: sl<RemoteCommandService>(),
        deviceRepository: sl<DeviceRepository>(),
        discoveryService: sl<DeviceDiscoveryService>(),
        layoutRepository: sl<LayoutRepository>(),
        transportLogReader: sl<TransportLogReader>(),
      ),
    );
  }
}
