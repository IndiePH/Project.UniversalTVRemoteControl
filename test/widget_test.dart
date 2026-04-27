// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/di_bootstrap.dart';
import 'package:one_remote/app/one_remote_app.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_remote/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/fake_hisense_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_lg_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_samsung_transport_client.dart';
import 'package:one_remote/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/data/in_memory_device_repository.dart';
import 'package:one_remote/remote_control/data/in_memory_remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/layout_position.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page.dart';
import 'package:one_remote/remote_control/presentation/pages/remote_home_page.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/theme/app_theme.dart';

void main() {
  test('menu defaults to the former pair grid position', () {
    final menuItem = buildInitialRemoteLayoutItems().singleWhere(
      (item) => item.id == 'menu',
    );

    expect(menuItem.col, 4);
    expect(menuItem.row, 0);
  });

  testWidgets('renders remote home page shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    DiBootstrap.initialize(AppEnvironment.debug);
    addTearDown(GetIt.instance.reset);

    await tester.pumpWidget(const OneRemoteApp());
    await tester.pump();

    expect(find.text('OneRemote'), findsOneWidget);
    expect(find.text('No TV connected'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Disconnected'), findsNothing);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('WWW'), findsOneWidget);
    expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_remote), findsOneWidget);
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
    expect(find.text('CH'), findsOneWidget);
    expect(find.text('VOL'), findsOneWidget);
  });

  testWidgets('disables remote actions when no active device', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    DiBootstrap.initialize(AppEnvironment.debug);
    addTearDown(GetIt.instance.reset);

    await tester.pumpWidget(const OneRemoteApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.power_settings_new));
    await tester.pump();

    expect(find.text('No device selected.'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('pairs to discovered TV and sends command from remote', (
    WidgetTester tester,
  ) async {
    GetIt.instance.registerSingleton<PrePairingStepsRegistry>(
      const DefaultPrePairingStepsRegistry(),
    );
    GetIt.instance.registerSingleton<PairingProgressHintRegistry>(
      const DefaultPairingProgressHintRegistry(),
    );
    GetIt.instance.registerSingleton<TvReachabilityService>(
      _StubTvReachabilityService(),
    );
    addTearDown(GetIt.instance.reset);

    final commandService = BrandRoutedRemoteCommandService(
      adapters: [
        SamsungAdapter(transportClient: FakeSamsungTransportClient()),
        LgAdapter(transportClient: FakeLgTransportClient()),
        HisenseAdapter(transportClient: FakeHisenseTransportClient()),
      ],
      variantRegistry: const DefaultVariantResolutionRegistry(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RemoteHomePage(
          commandService: commandService,
          deviceRepository: InMemoryDeviceRepository(),
          discoveryService: _StaticDiscoveryService(),
          layoutRepository: _InMemoryLayoutRepository(),
        ),
      ),
    );
    await tester.pump();

    // Open pairing via remote-selection header button.
    await tester.tap(find.byTooltip('Connect TV'));
    await tester.pumpAndSettle();
    expect(find.text('Select Remote'), findsOneWidget);

    await tester.pumpAndSettle();
    final discoveredTile = find.widgetWithText(ListTile, 'LG OLED - Bedroom');
    final listTile = tester.widget<ListTile>(discoveredTile);
    listTile.onTap?.call();
    await tester.pumpAndSettle();

    // Dismiss the pre-pairing confirmation dialog shown for LG.
    expect(find.text('Before pairing with LG'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Dismiss the pairing outcome dialog.
    expect(find.text('Paired successfully'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('LG OLED - Bedroom'), findsOneWidget);
    expect(find.textContaining('Connected:'), findsNothing);
    expect(find.textContaining('Last paired'), findsNothing);

    // Verify remote controls now dispatch command to the selected TV context.
    await tester.tap(find.byIcon(Icons.power_settings_new));
    await tester.pump();
    expect(find.text('Sent: power'), findsOneWidget);
  });

  testWidgets('clears active device when current paired TV is removed', (
    WidgetTester tester,
  ) async {
    GetIt.instance.registerSingleton<PrePairingStepsRegistry>(
      const DefaultPrePairingStepsRegistry(),
    );
    GetIt.instance.registerSingleton<PairingProgressHintRegistry>(
      const DefaultPairingProgressHintRegistry(),
    );
    GetIt.instance.registerSingleton<TvReachabilityService>(
      _StubTvReachabilityService(),
    );
    addTearDown(GetIt.instance.reset);

    final repository = InMemoryDeviceRepository();
    const activeDevice = TvDevice(
      id: 'samsung-living-room',
      displayName: 'Living Room TV',
      brand: TvBrand.samsung,
      capabilities: {
        DeviceCapability.keyCommands,
        DeviceCapability.powerControl,
      },
    );
    await repository.saveDevice(activeDevice);
    await repository.setLastUsedDevice(activeDevice.id);

    await tester.pumpWidget(
      MaterialApp(
        home: RemoteHomePage(
          commandService: InMemoryRemoteCommandService(),
          deviceRepository: repository,
          discoveryService: _EmptyDiscoveryService(),
          layoutRepository: _InMemoryLayoutRepository(),
        ),
      ),
    );
    await tester.pump();

    final appColors = AppTheme.createAppColors(brightness: Brightness.light);
    expect(_pairButtonColor(tester), appColors.remoteActionSuccessFill);

    await tester.tap(find.byTooltip('Connect TV'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Living Room TV'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('No TV connected'), findsOneWidget);
    expect(find.text('Reconnect TV to begin'), findsOneWidget);
    expect(find.text('Disconnected'), findsNothing);
    expect(_pairButtonColor(tester), appColors.remoteSurface);
  });

  testWidgets(
    'opens onboarding and troubleshooting guidance from help action',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PairingPage(
            commandService: InMemoryRemoteCommandService(),
            discoveryService: _EmptyDiscoveryService(),
            deviceRepository: InMemoryDeviceRepository(),
            stepsRegistry: const DefaultPrePairingStepsRegistry(),
            hintRegistry: const DefaultPairingProgressHintRegistry(),
            reachabilityService: _StubTvReachabilityService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(find.text('Need help finding your TV?'), findsOneWidget);
      expect(find.text('Permission and network checklist'), findsOneWidget);
      expect(find.text('Cannot find TV? Try this'), findsOneWidget);

      await tester.tap(find.text('Cannot find TV? Try this'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Use Add Manually with the TV IP address.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'removes active saved device after single confirmation and falls back last-used',
    (WidgetTester tester) async {
      final repository = InMemoryDeviceRepository();
      const activeDevice = TvDevice(
        id: 'samsung-living-room',
        displayName: 'Living Room TV',
        brand: TvBrand.samsung,
        capabilities: {
          DeviceCapability.keyCommands,
          DeviceCapability.textInput,
          DeviceCapability.powerControl,
        },
      );
      const fallbackDevice = TvDevice(
        id: 'lg-bedroom',
        displayName: 'Bedroom TV',
        brand: TvBrand.lg,
        capabilities: {
          DeviceCapability.keyCommands,
          DeviceCapability.powerControl,
        },
      );
      await repository.saveDevice(activeDevice);
      await repository.saveDevice(fallbackDevice);
      await repository.setLastUsedDevice(activeDevice.id);
      await repository.setLastSuccessfulPairingAt(
        deviceId: activeDevice.id,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PairingPage(
            commandService: InMemoryRemoteCommandService(),
            discoveryService: _StaticDiscoveryService(),
            deviceRepository: repository,
            stepsRegistry: const DefaultPrePairingStepsRegistry(),
            hintRegistry: const DefaultPairingProgressHintRegistry(),
            reachabilityService: _StubTvReachabilityService(),
            activeDeviceId: 'samsung-living-room',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Living Room TV'), findsOneWidget);

      await tester.drag(find.text('Living Room TV'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Type REMOVE'), findsNothing);
      expect(find.text('Living Room TV'), findsNothing);
      expect(find.text('Bedroom TV'), findsOneWidget);
      expect(find.textContaining('Removed Living Room TV'), findsOneWidget);

      final lastUsed = await repository.getLastUsedDevice();
      expect(lastUsed?.id, fallbackDevice.id);
    },
  );

  testWidgets(
    'removing non-active last-used device falls back without REMOVE guard',
    (WidgetTester tester) async {
      final repository = InMemoryDeviceRepository();
      const activeDevice = TvDevice(
        id: 'samsung-living-room',
        displayName: 'Living Room TV',
        brand: TvBrand.samsung,
        capabilities: {
          DeviceCapability.keyCommands,
          DeviceCapability.powerControl,
        },
      );
      const lastUsedDevice = TvDevice(
        id: 'lg-bedroom',
        displayName: 'Bedroom TV',
        brand: TvBrand.lg,
        capabilities: {
          DeviceCapability.keyCommands,
          DeviceCapability.powerControl,
        },
      );
      await repository.saveDevice(activeDevice);
      await repository.saveDevice(lastUsedDevice);
      await repository.setLastUsedDevice(lastUsedDevice.id);
      await repository.setLastSuccessfulPairingAt(
        deviceId: lastUsedDevice.id,
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PairingPage(
            commandService: InMemoryRemoteCommandService(),
            discoveryService: _StaticDiscoveryService(),
            deviceRepository: repository,
            stepsRegistry: const DefaultPrePairingStepsRegistry(),
            hintRegistry: const DefaultPairingProgressHintRegistry(),
            reachabilityService: _StubTvReachabilityService(),
            activeDeviceId: activeDevice.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Living Room TV'), findsOneWidget);
      expect(find.text('Bedroom TV'), findsOneWidget);

      await tester.drag(find.text('Bedroom TV'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Type REMOVE'), findsNothing);
      expect(find.text('Bedroom TV'), findsNothing);

      final lastUsed = await repository.getLastUsedDevice();
      expect(lastUsed?.id, activeDevice.id);
    },
  );
}

class _InMemoryLayoutRepository implements LayoutRepository {
  final Map<String, Map<String, LayoutPosition>> _layoutByDeviceId = {};

  @override
  Future<Map<String, LayoutPosition>> loadLayout({
    required String deviceId,
  }) async {
    return _layoutByDeviceId[deviceId] ?? <String, LayoutPosition>{};
  }

  @override
  Future<void> saveLayout({
    required String deviceId,
    required Map<String, LayoutPosition> positionsByItemId,
  }) async {
    _layoutByDeviceId[deviceId] = Map<String, LayoutPosition>.from(
      positionsByItemId,
    );
  }
}

class _StaticDiscoveryService implements DeviceDiscoveryService {
  static const List<TvDevice> _devices = [
    TvDevice(
      id: 'lg-bedroom',
      displayName: 'LG OLED - Bedroom',
      brand: TvBrand.lg,
      capabilities: {
        DeviceCapability.keyCommands,
        DeviceCapability.powerControl,
      },
    ),
  ];

  @override
  Future<List<TvDevice>> discoverDevices() async => _devices;
}

class _EmptyDiscoveryService implements DeviceDiscoveryService {
  @override
  Future<List<TvDevice>> discoverDevices() async => const <TvDevice>[];
}

class _StubTvReachabilityService implements TvReachabilityService {
  @override
  Future<bool> isReachable(TvDevice device) async => false;
}

Color? _pairButtonColor(WidgetTester tester) {
  final material = tester.widget<Material>(
    find.descendant(
      of: find.byTooltip('Connect TV'),
      matching: find.byType(Material),
    ),
  );
  return material.color;
}
