import 'package:flutter/material.dart';
import 'package:one_remote/src/app/transport_debug_settings.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/hisense/real_hisense_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/real_samsung_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/samsung_transport_log_reader.dart';
import 'package:one_remote/src/features/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/data/fake_device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/data/in_memory_device_repository.dart';
import 'package:one_remote/src/features/remote_control/data/shared_prefs_layout_repository.dart';
import 'package:one_remote/src/features/remote_control/data/ssdp_device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/remote_home_page.dart';
import 'package:one_remote/src/theme/app_theme.dart';

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
  static const String _tvHostOverride = String.fromEnvironment('TV_HOST_OVERRIDE');

  late final InMemoryDeviceRepository _deviceRepository = InMemoryDeviceRepository();
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
    final DeviceDiscoveryService discoveryService = _useFakeTransports
        ? FakeDeviceDiscoveryService()
        : SsdpDeviceDiscoveryService();
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
        deviceRepository: _deviceRepository,
        discoveryService: discoveryService,
        layoutRepository: _layoutRepository,
        transportLogReader: const SamsungTransportLogReader(),
        useFakeTransports: _useFakeTransports,
        compileTimeUseFakeTransports: _compileUseFakeTransports,
        onUseFakeTransportsChanged: _setUseFakeTransports,
      ),
    );
  }

  SamsungAdapter _buildSamsungAdapter() {
    if (_useFakeTransports) {
      return SamsungAdapter();
    }

    return SamsungAdapter(
      transportClient: RealSamsungTransportClient(
        hostResolver: _resolveSamsungHost,
      ),
    );
  }

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
