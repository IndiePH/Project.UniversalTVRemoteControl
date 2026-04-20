// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/src/app/one_remote_app.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/layout_repository.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/data/in_memory_device_repository.dart';
import 'package:one_remote/src/features/remote_control/data/in_memory_remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/src/features/remote_control/domain/models/layout_position.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/pairing_page.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/remote_home_page.dart';

void main() {
  testWidgets('renders remote home page shell', (WidgetTester tester) async {
    await tester.pumpWidget(const OneRemoteApp());
    await tester.pump();

    expect(find.text('OneRemote'), findsOneWidget);
    expect(find.text('No TV connected'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('WWW'), findsOneWidget);
    expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
    expect(find.text('CH'), findsOneWidget);
    expect(find.text('VOL'), findsOneWidget);
  });

  testWidgets('pairs to discovered TV and sends command from remote', (
    WidgetTester tester,
  ) async {
    final commandService = BrandRoutedRemoteCommandService(
      adapters: [SamsungAdapter(), LgAdapter(), HisenseAdapter()],
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

    // Open pairing via Wi-Fi button.
    await tester.tap(find.byIcon(Icons.wifi));
    await tester.pumpAndSettle();
    expect(find.text('Pair TV'), findsOneWidget);

    await tester.pumpAndSettle();
    final discoveredTile = find.widgetWithText(ListTile, 'LG OLED - Bedroom');
    final listTile = tester.widget<ListTile>(discoveredTile);
    listTile.onTap?.call();
    await tester.pumpAndSettle();

    expect(find.textContaining('Connected: LG OLED - Bedroom'), findsOneWidget);

    // Verify remote controls now dispatch command to the selected TV context.
    await tester.tap(find.byIcon(Icons.power_settings_new));
    await tester.pump();
    expect(find.text('Sent: power'), findsOneWidget);
  });

  testWidgets(
    'removes active saved device after REMOVE confirmation and falls back last-used',
    (
    WidgetTester tester,
  ) async {
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
          activeDeviceId: 'samsung-living-room',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Living Room TV'), findsOneWidget);

    final savedTile = find.widgetWithText(ListTile, 'Living Room TV');
    final listTile = tester.widget<ListTile>(savedTile);
    final deleteButton = listTile.trailing! as IconButton;
    deleteButton.onPressed?.call();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Type REMOVE'),
      'REMOVE',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Living Room TV'), findsNothing);
    expect(find.text('Bedroom TV'), findsOneWidget);
    expect(find.textContaining('Removed Living Room TV'), findsOneWidget);

    final lastUsed = await repository.getLastUsedDevice();
    expect(lastUsed?.id, fallbackDevice.id);
  });

  testWidgets('removing non-active last-used device falls back without REMOVE guard', (
    WidgetTester tester,
  ) async {
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
          activeDeviceId: activeDevice.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Living Room TV'), findsOneWidget);
    expect(find.text('Bedroom TV'), findsOneWidget);

    final savedTile = find.widgetWithText(ListTile, 'Bedroom TV');
    final listTile = tester.widget<ListTile>(savedTile);
    final deleteButton = listTile.trailing! as IconButton;
    deleteButton.onPressed?.call();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Type REMOVE'), findsNothing);
    expect(find.text('Bedroom TV'), findsNothing);

    final lastUsed = await repository.getLastUsedDevice();
    expect(lastUsed?.id, activeDevice.id);
  });
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
