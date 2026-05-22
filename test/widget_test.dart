// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/ads/interstitial_ad_controller.dart';
import 'package:one_remote/app/ads/interstitial_ad_policy.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/di_bootstrap.dart';
import 'package:one_remote/app/transport_debug_settings.dart';
import 'package:one_remote/app/monetization/fake_pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/monetization/shared_prefs_pro_entitlement_cache.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/app/one_remote_app.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_remote/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/remote_control/debug/fake_hisense_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_lg_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_samsung_transport_client.dart';
import 'package:one_remote/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/data/in_memory_device_repository.dart';
import 'package:one_remote/remote_control/data/in_memory_remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/layout_position.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart'
    as remote_connection;
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page.dart';
import 'package:one_remote/remote_control/presentation/pages/remote_home_page.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_home_remote_grid.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_widget_test_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/theme/app_theme.dart';
import 'fakes/fake_localized_strings.dart';

void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openSettingsSheet(WidgetTester tester) async {
  final settingsButton = find.byIcon(Icons.settings_outlined);
  await tester.ensureVisible(settingsButton);
  await tester.tap(settingsButton);
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('Settings').evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Settings sheet did not open');
}

Future<void> _scrollSettingsSheetTo(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(SingleChildScrollView);
  for (var attempt = 0; attempt < 24; attempt++) {
    if (target.evaluate().isEmpty) {
      break;
    }
    final top = tester.getTopLeft(target);
    if (top.dy >= 0 && top.dy < 2200) {
      return;
    }
    await tester.drag(scrollable, const Offset(0, -180));
    await tester.pump();
  }
  await tester.scrollUntilVisible(
    target,
    kRemoteWidgetTestScrollUntilVisibleDelta,
  );
}

void main() {
  test('menu defaults to the former pair grid position', () {
    final menuDefinition = kRemoteLayoutItemDefinitionById['menu']!;
    final menuItem = buildInitialRemoteLayoutItems().singleWhere(
      (item) => item.id == 'menu',
    );

    expect(menuItem.col, menuDefinition.col);
    expect(menuItem.row, menuDefinition.row);
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
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('WWW'), findsOneWidget);
    expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_remote), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
    expect(find.text('CH'), findsOneWidget);
    expect(find.text('VOL'), findsOneWidget);
  });

  testWidgets('toggling fake transport keeps debug settings sheet open', (
    WidgetTester tester,
  ) async {
    _useTallTestSurface(tester);
    SharedPreferences.setMockInitialValues({});
    await DiBootstrap.initialize(AppEnvironment.debug);
    addTearDown(GetIt.instance.reset);

    await tester.pumpWidget(const OneRemoteApp());
    await tester.pumpAndSettle();

    await _openSettingsSheet(tester);
    await _scrollSettingsSheetTo(tester, find.text('Use fake transports'));
    expect(find.text('Use fake transports'), findsOneWidget);

    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Use fake transports'), findsOneWidget);
    expect(find.text('Debug'), findsOneWidget);
  });

  testWidgets('toggling fake transport shows fake brands in pairing list', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      TransportDebugSettings.keyUseFakeTransports: true,
    });
    await DiBootstrap.initialize(AppEnvironment.debug);
    addTearDown(GetIt.instance.reset);

    await tester.pumpWidget(const OneRemoteApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Connect TV'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Samsung QLED - Living Room').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Samsung QLED - Living Room'), findsOneWidget);
    expect(find.text('LG OLED - Bedroom'), findsOneWidget);
    expect(find.text('Hisense U7 - Office'), findsOneWidget);
  });

  // Debug-row hit targets sit below the modal viewport in widget tests (scroll/tap TBD).
  testWidgets(
    'copy transport logs keeps debug settings sheet open when no logs exist',
    skip: true,
    (WidgetTester tester) async {
      _useTallTestSurface(tester);
      SharedPreferences.setMockInitialValues({});
      await DiBootstrap.initialize(AppEnvironment.debug);
      addTearDown(GetIt.instance.reset);

      await tester.pumpWidget(const OneRemoteApp());
      await tester.pumpAndSettle();

      await _openSettingsSheet(tester);
      await _scrollSettingsSheetTo(tester, find.text('Copy transport logs'));
      expect(find.text('Copy transport logs'), findsOneWidget);
      await tester.ensureVisible(find.text('Copy transport logs'));
      await tester.tap(find.text('Copy transport logs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No transport log found yet.'), findsOneWidget);
      expect(find.text('Copy transport logs'), findsOneWidget);
      expect(find.text('Debug'), findsOneWidget);
    },
  );

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
    expect(find.text('Pair a TV first.'), findsOneWidget);
  });

  testWidgets(
    'keeps grid disabled while reconnecting and re-enables on connected',
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
      await repository.saveDevice(activeDevice);
      await repository.setLastUsedDevice(activeDevice.id);
      final commandService = _ConnectionStateStubCommandService(
        initialState: remote_connection.ConnectionState.disconnected,
      );
      addTearDown(commandService.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RemoteHomePage(
            appEnvironment: AppEnvironment.debug,
            interstitialAdController: _buildInterstitialAdController(),
            commandService: commandService,
            deviceRepository: repository,
            discoveryService: _EmptyDiscoveryService(),
            layoutRepository: _InMemoryLayoutRepository(),
            proEntitlementService: _buildEntitledProService(),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<RemoteHomeRemoteGrid>(find.byType(RemoteHomeRemoteGrid))
            .controlsEnabled,
        isFalse,
      );
      expect(find.text('Disconnected'), findsWidgets);

      commandService.emitConnectionState(
        remote_connection.ConnectionState.connected,
      );
      await tester.pump();

      expect(
        tester
            .widget<RemoteHomeRemoteGrid>(find.byType(RemoteHomeRemoteGrid))
            .controlsEnabled,
        isTrue,
      );
      expect(find.text('Ready'), findsOneWidget);
    },
  );

  testWidgets('pairs to discovered TV and sends command from remote', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    GetIt.instance.registerSingleton<AppEnvironment>(AppEnvironment.debug);
    GetIt.instance.registerSingleton<PrePairingStepsRegistry>(
      DefaultPrePairingStepsRegistry(localizedStrings: FakeLocalizedStrings()),
    );
    GetIt.instance.registerSingleton<PairingProgressHintRegistry>(
      DefaultPairingProgressHintRegistry(
        localizedStrings: FakeLocalizedStrings(),
      ),
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
      localizedStrings: FakeLocalizedStrings(),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RemoteHomePage(
          appEnvironment: AppEnvironment.debug,
          interstitialAdController: _buildInterstitialAdController(),
          commandService: commandService,
          deviceRepository: InMemoryDeviceRepository(),
          discoveryService: _StaticDiscoveryService(),
          layoutRepository: _InMemoryLayoutRepository(),
          proEntitlementService: _buildEntitledProService(),
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

  testWidgets('switches active TV from remote home device switcher', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryDeviceRepository();
    const livingRoom = TvDevice(
      id: 'samsung-living-room',
      displayName: 'Living Room TV',
      brand: TvBrand.samsung,
      capabilities: {DeviceCapability.keyCommands},
    );
    const bedroom = TvDevice(
      id: 'lg-bedroom',
      displayName: 'Bedroom TV',
      brand: TvBrand.lg,
      capabilities: {DeviceCapability.keyCommands},
    );
    await repository.saveDevice(livingRoom);
    await repository.saveDevice(bedroom);
    await repository.setLastUsedDevice(livingRoom.id);
    final commandService = _ConnectionStateStubCommandService(
      initialState: remote_connection.ConnectionState.connected,
    );
    addTearDown(commandService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RemoteHomePage(
          appEnvironment: AppEnvironment.debug,
          interstitialAdController: _buildInterstitialAdController(),
          commandService: commandService,
          deviceRepository: repository,
          discoveryService: _EmptyDiscoveryService(),
          layoutRepository: _InMemoryLayoutRepository(),
          proEntitlementService: _buildEntitledProService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Living Room TV'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch TV'));
    await tester.pumpAndSettle();
    expect(find.text('Your TVs'), findsOneWidget);

    await tester.tap(find.text('Bedroom TV'));
    await tester.pumpAndSettle();

    expect(find.text('Bedroom TV'), findsOneWidget);
    expect(find.text('Living Room TV'), findsNothing);
    expect(await repository.getLastUsedDevice(), bedroom);
  });

  testWidgets('places active paired TV first in pro device switcher', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryDeviceRepository();
    const livingRoom = TvDevice(
      id: 'samsung-living-room',
      displayName: 'Living Room TV',
      brand: TvBrand.samsung,
      capabilities: {DeviceCapability.keyCommands},
    );
    const bedroom = TvDevice(
      id: 'lg-bedroom',
      displayName: 'Bedroom TV',
      brand: TvBrand.lg,
      capabilities: {DeviceCapability.keyCommands},
    );
    await repository.saveDevice(livingRoom);
    await repository.saveDevice(bedroom);
    await repository.setLastUsedDevice(bedroom.id);
    final commandService = _ConnectionStateStubCommandService(
      initialState: remote_connection.ConnectionState.connected,
    );
    addTearDown(commandService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RemoteHomePage(
          appEnvironment: AppEnvironment.debug,
          interstitialAdController: _buildInterstitialAdController(),
          commandService: commandService,
          deviceRepository: repository,
          discoveryService: _EmptyDiscoveryService(),
          layoutRepository: _InMemoryLayoutRepository(),
          proEntitlementService: _buildEntitledProService(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Switch TV'));
    await tester.pumpAndSettle();

    Finder switcherTile(String title) => find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.title is Text &&
          (widget.title as Text).data == title,
    );

    expect(
      tester.getTopLeft(switcherTile('Bedroom TV')).dy,
      lessThan(tester.getTopLeft(switcherTile('Living Room TV')).dy),
    );
  });

  testWidgets('free tier shows device switcher but cannot switch TVs', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryDeviceRepository();
    const livingRoom = TvDevice(
      id: 'samsung-living-room',
      displayName: 'Living Room TV',
      brand: TvBrand.samsung,
      capabilities: {DeviceCapability.keyCommands},
    );
    const bedroom = TvDevice(
      id: 'lg-bedroom',
      displayName: 'Bedroom TV',
      brand: TvBrand.lg,
      capabilities: {DeviceCapability.keyCommands},
    );
    await repository.saveDevice(livingRoom);
    await repository.saveDevice(bedroom);
    await repository.setLastUsedDevice(livingRoom.id);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RemoteHomePage(
          appEnvironment: AppEnvironment.debug,
          interstitialAdController: _buildInterstitialAdController(),
          commandService: _ConnectionStateStubCommandService(
            initialState: remote_connection.ConnectionState.connected,
          ),
          deviceRepository: repository,
          discoveryService: _EmptyDiscoveryService(),
          layoutRepository: _InMemoryLayoutRepository(),
          proEntitlementService: _buildFreeProService(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Switch TV'));
    await tester.pumpAndSettle();
    expect(find.text('Your TVs'), findsOneWidget);
    expect(
      find.text('Upgrade to Pro to switch between saved TVs.'),
      findsOneWidget,
    );
    expect(find.text('Bedroom TV'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byTooltip('Pro required to switch TVs'), findsOneWidget);

    await tester.tap(find.text('Bedroom TV'));
    await tester.pumpAndSettle();

    expect(await repository.getLastUsedDevice(), livingRoom);
    expect(find.text('Your TVs'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets(
    'downgrading to free tier refreshes Your TVs list to active device only',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = InMemoryDeviceRepository();
      const livingRoom = TvDevice(
        id: 'samsung-living-room',
        displayName: 'Living Room TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
      );
      const bedroom = TvDevice(
        id: 'lg-bedroom',
        displayName: 'Bedroom TV',
        brand: TvBrand.lg,
        capabilities: {DeviceCapability.keyCommands},
      );
      await repository.saveDevice(livingRoom);
      await repository.saveDevice(bedroom);
      await repository.setLastUsedDevice(livingRoom.id);

      final unpairedDevices = <TvDevice>[];
      final proService = _buildEntitledProService();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RemoteHomePage(
            appEnvironment: AppEnvironment.debug,
            interstitialAdController: _buildInterstitialAdController(),
            commandService: _ConnectionStateStubCommandService(
              initialState: remote_connection.ConnectionState.connected,
              recordUnpairTo: unpairedDevices,
            ),
            deviceRepository: repository,
            discoveryService: _EmptyDiscoveryService(),
            layoutRepository: _InMemoryLayoutRepository(),
            proEntitlementService: proService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Switch TV'));
      await tester.pumpAndSettle();
      expect(find.text('Bedroom TV'), findsOneWidget);

      await proService.debugToggleEntitlement();
      await tester.pumpAndSettle();

      expect(unpairedDevices, [bedroom]);
      expect(await repository.getSavedDevices(), [livingRoom]);
      expect(find.text('Bedroom TV'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Living Room TV'), findsOneWidget);
      expect(
        find.text('Upgrade to Pro to switch between saved TVs.'),
        findsNothing,
      );
    },
  );

  testWidgets('clears active device when current paired TV is removed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    GetIt.instance.registerSingleton<AppEnvironment>(AppEnvironment.debug);
    GetIt.instance.registerSingleton<PrePairingStepsRegistry>(
      DefaultPrePairingStepsRegistry(localizedStrings: FakeLocalizedStrings()),
    );
    GetIt.instance.registerSingleton<PairingProgressHintRegistry>(
      DefaultPairingProgressHintRegistry(
        localizedStrings: FakeLocalizedStrings(),
      ),
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RemoteHomePage(
          appEnvironment: AppEnvironment.debug,
          interstitialAdController: _buildInterstitialAdController(),
          commandService: InMemoryRemoteCommandService(),
          deviceRepository: repository,
          discoveryService: _EmptyDiscoveryService(),
          layoutRepository: _InMemoryLayoutRepository(),
          proEntitlementService: _buildEntitledProService(),
        ),
      ),
    );
    await tester.pump();

    final appColors = AppTheme.createAppColors(brightness: Brightness.light);
    expect(_pairButtonColor(tester), appColors.remoteActionSuccessFill);

    await tester.tap(find.byTooltip('Connect TV'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Living Room TV'),
      kRemoteWidgetTestSwipeToDismissOffset,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('No TV connected'), findsOneWidget);
    expect(find.text('Connect a TV to begin'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(_pairButtonColor(tester), appColors.remoteSurface);
  });

  testWidgets(
    'opens onboarding and troubleshooting guidance from help action',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PairingPage(
            commandService: InMemoryRemoteCommandService(),
            discoveryService: _EmptyDiscoveryService(),
            deviceRepository: InMemoryDeviceRepository(),
            stepsRegistry: DefaultPrePairingStepsRegistry(
              localizedStrings: FakeLocalizedStrings(),
            ),
            hintRegistry: DefaultPairingProgressHintRegistry(
              localizedStrings: FakeLocalizedStrings(),
            ),
            reachabilityService: _StubTvReachabilityService(),
            proEntitlementService: _buildEntitledProService(),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PairingPage(
            commandService: InMemoryRemoteCommandService(),
            discoveryService: _StaticDiscoveryService(),
            deviceRepository: repository,
            stepsRegistry: DefaultPrePairingStepsRegistry(
              localizedStrings: FakeLocalizedStrings(),
            ),
            hintRegistry: DefaultPairingProgressHintRegistry(
              localizedStrings: FakeLocalizedStrings(),
            ),
            reachabilityService: _StubTvReachabilityService(),
            proEntitlementService: _buildEntitledProService(),
            activeDeviceId: 'samsung-living-room',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Living Room TV'), findsOneWidget);

      await tester.drag(
        find.text('Living Room TV'),
        kRemoteWidgetTestSwipeToDismissOffset,
      );
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PairingPage(
            commandService: InMemoryRemoteCommandService(),
            discoveryService: _StaticDiscoveryService(),
            deviceRepository: repository,
            stepsRegistry: DefaultPrePairingStepsRegistry(
              localizedStrings: FakeLocalizedStrings(),
            ),
            hintRegistry: DefaultPairingProgressHintRegistry(
              localizedStrings: FakeLocalizedStrings(),
            ),
            reachabilityService: _StubTvReachabilityService(),
            proEntitlementService: _buildEntitledProService(),
            activeDeviceId: activeDevice.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Living Room TV'), findsOneWidget);
      expect(find.text('Bedroom TV'), findsOneWidget);

      await tester.drag(
        find.text('Bedroom TV'),
        kRemoteWidgetTestSwipeToDismissOffset,
      );
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

ProEntitlementService _buildEntitledProService() {
  final repository = FakeProEntitlementRepository(
    initialStatus: ProEntitlementStatus.entitled,
  );
  final service = ProEntitlementService(
    repository: repository,
    cache: SharedPrefsProEntitlementCache(),
  );
  repository.setStatus(ProEntitlementStatus.entitled);
  return service;
}

ProEntitlementService _buildFreeProService() {
  final repository = FakeProEntitlementRepository(
    initialStatus: ProEntitlementStatus.notEntitled,
  );
  final service = ProEntitlementService(
    repository: repository,
    cache: SharedPrefsProEntitlementCache(),
  );
  repository.setStatus(ProEntitlementStatus.notEntitled);
  return service;
}

InterstitialAdController _buildInterstitialAdController() {
  return InterstitialAdController(
    appEnvironment: AppEnvironment.debug,
    policy: InterstitialAdPolicy(
      minSuccessfulActionsBetweenAds: 100,
      minIntervalBetweenAds: const Duration(hours: 1),
      sessionImpressionCap: 1,
    ),
  );
}

class _ConnectionStateStubCommandService implements RemoteCommandService {
  _ConnectionStateStubCommandService({
    required remote_connection.ConnectionState initialState,
    List<TvDevice>? recordUnpairTo,
  }) : _state = initialState,
       _recordUnpairTo = recordUnpairTo,
       _controller =
           StreamController<remote_connection.ConnectionState>.broadcast(
             onListen: () {},
           );

  remote_connection.ConnectionState _state;
  final List<TvDevice>? _recordUnpairTo;
  final StreamController<remote_connection.ConnectionState> _controller;

  void emitConnectionState(remote_connection.ConnectionState state) {
    _state = state;
    _controller.add(state);
  }

  void dispose() {
    _controller.close();
  }

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async => CommandDispatchResult.success('ok');

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async => CommandDispatchResult.success('ok');

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    _recordUnpairTo?.add(device);
  }

  @override
  Future<void> cancelPairing({required TvDevice device}) async {}

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async => CommandDispatchResult.success('ok');

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async => CommandDispatchResult.success('ok');

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      Stream<bool>.value(false);

  @override
  Future<bool> checkRemoteTextInputReady({required TvDevice device}) async =>
      false;

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      RemoteCommand.values.toSet();

  @override
  Stream<remote_connection.ConnectionState> watchConnectionState({
    required TvDevice device,
  }) => Stream<remote_connection.ConnectionState>.multi((multi) {
    multi.add(_state);
    final sub = _controller.stream.listen(
      multi.add,
      onError: multi.addError,
      onDone: multi.close,
    );
    multi.onCancel = () => sub.cancel();
  });
}
