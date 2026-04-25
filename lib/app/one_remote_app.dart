import 'package:flutter/material.dart';
import 'package:one_remote/app/app_composition_root.dart';
import 'package:one_remote/app/transport_debug_settings.dart';
import 'package:one_remote/remote_control/data/shared_prefs_device_repository.dart';
import 'package:one_remote/remote_control/data/shared_prefs_layout_repository.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_log_reader.dart';
import 'package:one_remote/remote_control/presentation/pages/remote_home_page.dart';
import 'package:one_remote/theme/app_theme.dart';

class OneRemoteApp extends StatefulWidget {
  const OneRemoteApp({super.key});

  @override
  State<OneRemoteApp> createState() => _OneRemoteAppState();
}

class _OneRemoteAppState extends State<OneRemoteApp> {
  static const bool _compileUseFakeTransports = bool.fromEnvironment(
    'USE_FAKE_TRANSPORTS',
    defaultValue: false,
  );

  late final SharedPrefsDeviceRepository _deviceRepository = SharedPrefsDeviceRepository();
  late final SharedPrefsLayoutRepository _layoutRepository = SharedPrefsLayoutRepository();

  bool _useFakeTransports = _compileUseFakeTransports;

  @override
  void initState() {
    super.initState();
    _loadTransportOverride();
  }

  Future<void> _loadTransportOverride() async {
    final stored = await TransportDebugSettings.readUseFakeTransportsOverride();
    if (!mounted) return;
    setState(() {
      _useFakeTransports = stored ?? _compileUseFakeTransports;
    });
  }

  Future<void> _setUseFakeTransports(bool value) async {
    await TransportDebugSettings.writeUseFakeTransports(value);
    if (!mounted) return;
    setState(() => _useFakeTransports = value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneRemote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: RemoteHomePage(
        commandService: AppCompositionRoot.buildCommandService(
          _useFakeTransports,
          _deviceRepository,
        ),
        deviceRepository: _deviceRepository,
        discoveryService: AppCompositionRoot.buildDiscoveryService(_useFakeTransports),
        layoutRepository: _layoutRepository,
        transportLogReader: const SamsungTransportLogReader(),
        useFakeTransports: _useFakeTransports,
        compileTimeUseFakeTransports: _compileUseFakeTransports,
        onUseFakeTransportsChanged: _setUseFakeTransports,
      ),
    );
  }
}
