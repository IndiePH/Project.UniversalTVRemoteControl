import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart'
    as remote_connection;
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/pin_format.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import 'package:one_remote/app/monetization/fake_pro_entitlement_repository.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/app/monetization/shared_prefs_pro_entitlement_cache.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_widget_test_metrics.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page.dart';

void main() {
  ProEntitlementService buildProService({
    ProEntitlementStatus status = ProEntitlementStatus.entitled,
  }) {
    final repository = FakeProEntitlementRepository(initialStatus: status);
    final service = ProEntitlementService(
      repository: repository,
      cache: SharedPrefsProEntitlementCache(),
    );
    repository.setStatus(status);
    return service;
  }

  Widget buildPage({
    required RemoteCommandService commandService,
    _StubPrePairingStepsRegistry? stepsRegistry,
    _StubPairingProgressHintRegistry? hintRegistry,
    DeviceRepository? deviceRepository,
    DeviceDiscoveryService? discoveryService,
    TvReachabilityService? reachabilityService,
    ProEntitlementService? proEntitlementService,
    String? activeDeviceId,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PairingPage(
        commandService: commandService,
        discoveryService: discoveryService ?? _StubDiscoveryService(),
        deviceRepository: deviceRepository ?? _StubDeviceRepository(),
        stepsRegistry: stepsRegistry ?? _StubPrePairingStepsRegistry(),
        hintRegistry: hintRegistry ?? _StubPairingProgressHintRegistry(),
        reachabilityService:
            reachabilityService ?? _StubTvReachabilityService(),
        proEntitlementService: proEntitlementService ?? buildProService(),
        activeDeviceId: activeDeviceId,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Outcome dialog — success
  // ---------------------------------------------------------------------------

  group('outcome dialog on success', () {
    testWidgets('shows success dialog after successful pairing', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('LG TV'));
      await tester.pumpAndSettle();

      expect(find.text('Paired successfully'), findsOneWidget);
      expect(find.text('LG TV is ready to use.'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('navigates away after tapping Done on success', (tester) async {
      TvDevice? poppedDevice;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedDevice = await Navigator.of(context).push<TvDevice>(
                  MaterialPageRoute(
                    builder: (_) => PairingPage(
                      commandService: _StubCommandService(
                        preparePairingResult: CommandDispatchResult.success(
                          'OK',
                        ),
                      ),
                      discoveryService: _StubDiscoveryService(),
                      deviceRepository: _StubDeviceRepository(),
                      stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
                      hintRegistry: _StubPairingProgressHintRegistry(),
                      reachabilityService: _StubTvReachabilityService(),
                      proEntitlementService: buildProService(),
                    ),
                  ),
                );
              },
              child: const Text('Open pairing'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open pairing'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('LG TV'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(poppedDevice, isNotNull);
      expect(poppedDevice!.displayName, 'LG TV');
    });
  });

  // ---------------------------------------------------------------------------
  // Outcome dialog — failure
  // ---------------------------------------------------------------------------

  group('outcome dialog on failure', () {
    testWidgets('shows failure dialog after failed pairing', (tester) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.failure(
              'Connection refused',
            ),
          ),
          stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('LG TV'));
      await tester.pumpAndSettle();

      expect(find.text('Pairing failed'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('stays on pairing page after tapping Dismiss on failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.failure(
              'Connection refused',
            ),
          ),
          stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('LG TV'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.byType(PairingPage), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Progress hint
  // ---------------------------------------------------------------------------

  group('progress hint', () {
    testWidgets('shows hint from registry while pairing is in progress', (
      tester,
    ) async {
      const hint = 'Look at your TV screen.';
      await tester.pumpWidget(
        buildPage(
          commandService: _SlowCommandService(),
          stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
          hintRegistry: _StubPairingProgressHintRegistry(hint: hint),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('LG TV'));
      await tester.pump();

      expect(find.text(hint), findsOneWidget);
    });

    testWidgets('shows no hint when registry returns null for brand', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _SlowCommandService(),
          stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
          hintRegistry: _StubPairingProgressHintRegistry(hint: null),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('LG TV'));
      await tester.pump();

      expect(
        find.text('Look at your TV screen and accept the pairing prompt.'),
        findsNothing,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Grouped list
  // ---------------------------------------------------------------------------

  group('grouped list', () {
    const savedDevice = TvDevice(
      id: 'lg-saved',
      displayName: 'Saved TV',
      brand: TvBrand.lg,
      capabilities: {DeviceCapability.keyCommands},
    );

    testWidgets('saved device appears under Paired section header', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: [savedDevice]),
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pump();

      expect(find.text('Paired'), findsOneWidget);
      expect(find.text('Saved TV'), findsOneWidget);
    });

    testWidgets('Paired section lists active TV first then other saved TVs', (
      tester,
    ) async {
      const activeDevice = TvDevice(
        id: 'lg-active',
        displayName: 'Active TV',
        brand: TvBrand.lg,
        capabilities: {DeviceCapability.keyCommands},
      );
      const otherDevice = TvDevice(
        id: 'samsung-other',
        displayName: 'Other TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
      );
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(
            savedDevices: [otherDevice, activeDevice],
          ),
          activeDeviceId: activeDevice.id,
        ),
      );
      await tester.pump();

      expect(find.text('Paired'), findsOneWidget);
      expect(find.text('Active TV'), findsOneWidget);
      expect(find.text('Other TV'), findsOneWidget);
    });

    testWidgets('Paired list scrolls when more than three TVs are saved', (
      tester,
    ) async {
      const devices = [
        TvDevice(
          id: 'tv-1',
          displayName: 'TV One',
          brand: TvBrand.lg,
          capabilities: {DeviceCapability.keyCommands},
        ),
        TvDevice(
          id: 'tv-2',
          displayName: 'TV Two',
          brand: TvBrand.samsung,
          capabilities: {DeviceCapability.keyCommands},
        ),
        TvDevice(
          id: 'tv-3',
          displayName: 'TV Three',
          brand: TvBrand.lg,
          capabilities: {DeviceCapability.keyCommands},
        ),
        TvDevice(
          id: 'tv-4',
          displayName: 'TV Four',
          brand: TvBrand.hisense,
          capabilities: {DeviceCapability.keyCommands},
        ),
      ];
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: devices),
          activeDeviceId: 'tv-1',
        ),
      );
      await tester.pump();

      expect(find.text('TV Four'), findsNothing);
      await tester.drag(
        find.byKey(const Key('pairing_paired_devices_list')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(find.text('TV Four'), findsOneWidget);

      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      expect(scrollbar.thumbVisibility, isTrue);
    });

    testWidgets('Paired list has no scrollbar when at most three TVs', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(
            savedDevices: [
              const TvDevice(
                id: 'tv-1',
                displayName: 'TV One',
                brand: TvBrand.lg,
                capabilities: {DeviceCapability.keyCommands},
              ),
              const TvDevice(
                id: 'tv-2',
                displayName: 'TV Two',
                brand: TvBrand.samsung,
                capabilities: {DeviceCapability.keyCommands},
              ),
            ],
          ),
          activeDeviceId: 'tv-1',
        ),
      );
      await tester.pump();

      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('tapping already-paired discovery TV does not start pairing', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: [lgDevice]),
          activeDeviceId: lgDevice.id,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('LG TV').last);
      await tester.pumpAndSettle();

      expect(find.text('Paired successfully'), findsNothing);
      expect(find.text('LG TV is already paired.'), findsOneWidget);
    });

    testWidgets('tapping active paired TV shows already-using feedback', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: [lgDevice]),
          activeDeviceId: lgDevice.id,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('LG TV').first);
      await tester.pumpAndSettle();

      expect(find.text("You're already using LG TV."), findsOneWidget);
      expect(find.text('Paired successfully'), findsNothing);
    });

    testWidgets('free tier keeps only active paired TV on load', (
      tester,
    ) async {
      const activeDevice = TvDevice(
        id: 'tv-1',
        displayName: 'TV One',
        brand: TvBrand.lg,
        capabilities: {DeviceCapability.keyCommands},
      );
      const otherDevice = TvDevice(
        id: 'tv-2',
        displayName: 'TV Two',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
      );
      final repo = _MutableSpyDeviceRepository(
        savedDevices: [activeDevice, otherDevice],
      );
      final unpairedDevices = <TvDevice>[];
      final discoveryService = _CountingDiscoveryService();
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
            recordUnpairTo: unpairedDevices,
          ),
          deviceRepository: repo,
          discoveryService: discoveryService,
          activeDeviceId: activeDevice.id,
          proEntitlementService: buildProService(
            status: ProEntitlementStatus.notEntitled,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TV One'), findsOneWidget);
      expect(find.text('TV Two'), findsNothing);
      expect(unpairedDevices, [otherDevice]);
      expect(repo.removedDeviceIds, [otherDevice.id]);
      expect(discoveryService.callCount, 2);
    });

    testWidgets(
      'free tier unpairs active TV before pairing a different discovered TV',
      (tester) async {
        final repo = _MutableSpyDeviceRepository(savedDevices: [lgDevice]);
        final unpairedDevices = <TvDevice>[];
        final commandService = _StubCommandService(
          preparePairingResult: CommandDispatchResult.success('OK'),
          recordUnpairTo: unpairedDevices,
        );
        await tester.pumpWidget(
          buildPage(
            commandService: commandService,
            deviceRepository: repo,
            activeDeviceId: lgDevice.id,
            proEntitlementService: buildProService(
              status: ProEntitlementStatus.notEntitled,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Hisense TV'));
        await tester.pumpAndSettle();

        expect(unpairedDevices, [lgDevice]);
        expect(repo.removedDeviceIds, [lgDevice.id]);
        expect(find.text('Paired successfully'), findsOneWidget);
      },
    );

    testWidgets('discovery results appear under Available section header', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Available'), findsOneWidget);
      expect(find.text('LG TV'), findsOneWidget);
      expect(find.text('Hisense TV'), findsOneWidget);
    });

    testWidgets('swipe left on paired TV shows remove confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: [savedDevice]),
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pump();

      await tester.drag(
        find.text('Saved TV'),
        kRemoteWidgetTestSwipeToDismissOffset,
      );
      await tester.pumpAndSettle();

      expect(find.text('Remove saved device?'), findsOneWidget);
    });

    testWidgets('cancelling swipe keeps item in paired list', (tester) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: [savedDevice]),
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pump();

      await tester.drag(
        find.text('Saved TV'),
        kRemoteWidgetTestSwipeToDismissOffset,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Saved TV'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Rename flow
  // ---------------------------------------------------------------------------

  group('rename paired TV', () {
    const savedDevice = TvDevice(
      id: 'lg-saved',
      displayName: 'Saved TV',
      brand: TvBrand.lg,
      capabilities: {DeviceCapability.keyCommands},
    );

    testWidgets(
      'tapping rename button opens rename dialog pre-filled with current name',
      (tester) async {
        await tester.pumpWidget(
          buildPage(
            commandService: _StubCommandService(
              preparePairingResult: CommandDispatchResult.success('OK'),
            ),
            deviceRepository: _StubDeviceRepository(
              savedDevices: [savedDevice],
            ),
            activeDeviceId: savedDevice.id,
          ),
        );
        await tester.pump();

        await tester.tap(find.byTooltip('Rename'));
        await tester.pumpAndSettle();

        expect(find.text('Rename TV'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Saved TV'), findsOneWidget);
      },
    );

    testWidgets('submitting new name saves device with updated displayName', (
      tester,
    ) async {
      final repo = _SpyDeviceRepository(savedDevices: [savedDevice]);
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: repo,
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Living Room TV');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(repo.lastSavedDevice?.displayName, 'Living Room TV');
    });

    testWidgets('cancelling rename does not call saveDevice', (tester) async {
      final repo = _SpyDeviceRepository(savedDevices: [savedDevice]);
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: repo,
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Rename'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.lastSavedDevice, isNull);
    });

    testWidgets('submitting empty name shows validation error', (tester) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: [savedDevice]),
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a name.'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // FAB layout
  // ---------------------------------------------------------------------------

  group('FAB layout', () {
    testWidgets('search FAB is present', (tester) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Scan for TVs'), findsOneWidget);
      expect(
        find.widgetWithIcon(FloatingActionButton, Icons.search),
        findsOneWidget,
      );
    });

    testWidgets('keyboard FAB is present', (tester) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Add manually'), findsOneWidget);
      expect(
        find.widgetWithIcon(FloatingActionButton, Icons.keyboard),
        findsOneWidget,
      );
    });

    testWidgets('tapping search FAB re-triggers scan loading indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          discoveryService: _SlowDiscoveryService(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Scan for TVs'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping keyboard FAB opens manual add sheet', (tester) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Add manually'));
      await tester.pumpAndSettle();

      expect(find.text('Manual Pairing'), findsOneWidget);
      expect(find.text('Add Manually'), findsOneWidget);
    });

    testWidgets('manual add sheet initiates pairing on valid IP', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Add manually'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '192.168.1.99');
      await tester.tap(find.text('Add Manually'));
      await tester.pumpAndSettle();

      expect(find.text('Paired successfully'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // PIN flow regression
  // ---------------------------------------------------------------------------

  group('pin flow regression', () {
    testWidgets('prompts for PIN and shows success dialog after correct PIN', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.pinRequired(
              'Needs PIN',
            ),
            submitPairingResults: [CommandDispatchResult.success('OK')],
          ),
          stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Hisense TV'));
      await tester.pumpAndSettle();

      expect(find.text('Enter TV pairing code'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '1234',
      );
      await tester.tap(find.text('Submit code'));
      await tester.pumpAndSettle();

      expect(find.text('Paired successfully'), findsOneWidget);
    });

    testWidgets(
      'PIN dialog shows 6-char label, maxLength 6, visiblePassword keyboard for sixCharHex format',
      (tester) async {
        await tester.pumpWidget(
          buildPage(
            commandService: _StubCommandService(
              preparePairingResult: CommandDispatchResult.pinRequired(
                'Enter 6-character code',
                pinFormat: PinFormat.sixCharHex,
              ),
              submitPairingResults: [CommandDispatchResult.success('OK')],
            ),
            stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Hisense TV'));
        await tester.pumpAndSettle();

        expect(find.text('6-character code (e.g. A4B2C1)'), findsOneWidget);

        final tf = tester.widget<TextField>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
        );
        expect(tf.maxLength, 6);
        expect(tf.keyboardType, TextInputType.visiblePassword);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Connection indicator
  // ---------------------------------------------------------------------------

  group('connection indicator', () {
    const savedDevice = TvDevice(
      id: 'lg-saved',
      displayName: 'Saved TV',
      brand: TvBrand.lg,
      capabilities: {DeviceCapability.keyCommands},
    );

    testWidgets('shows spinner while reachability probe is pending', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: [savedDevice]),
          reachabilityService: _NeverResolvingReachabilityService(),
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is CircularProgressIndicator && w.strokeWidth == 1.5,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows wifi icon when device is reachable', (tester) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: [savedDevice]),
          reachabilityService: const _StubTvReachabilityService(reachable: true),
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });

    testWidgets('shows wifi_off when device is unreachable', (tester) async {
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(savedDevices: [savedDevice]),
          reachabilityService: const _StubTvReachabilityService(reachable: false),
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsNothing);
    });

    testWidgets('probes all paired devices including non-active', (
      tester,
    ) async {
      const otherDevice = TvDevice(
        id: 'samsung-other',
        displayName: 'Other TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
      );
      final spy = _SpyTvReachabilityService();
      await tester.pumpWidget(
        buildPage(
          commandService: _StubCommandService(
            preparePairingResult: CommandDispatchResult.success('OK'),
          ),
          deviceRepository: _StubDeviceRepository(
            savedDevices: [savedDevice, otherDevice],
          ),
          reachabilityService: spy,
          activeDeviceId: savedDevice.id,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        spy.probedDeviceIds,
        containsAll([savedDevice.id, otherDevice.id]),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _StubCommandService implements RemoteCommandService {
  _StubCommandService({
    required this.preparePairingResult,
    this.submitPairingResults = const [],
    this.recordUnpairTo,
  });

  final CommandDispatchResult preparePairingResult;
  final List<CommandDispatchResult> submitPairingResults;
  final List<TvDevice>? recordUnpairTo;
  int _submitIndex = 0;

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async => preparePairingResult;

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async {
    if (submitPairingResults.isEmpty) {
      return CommandDispatchResult.success('OK');
    }
    final i = _submitIndex.clamp(0, submitPairingResults.length - 1);
    _submitIndex++;
    return submitPairingResults[i];
  }

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    recordUnpairTo?.add(device);
  }

  @override
  Future<void> cancelPairing({required TvDevice device}) async {}

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async => CommandDispatchResult.unsupported('unused');

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async => CommandDispatchResult.unsupported('unused');

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      const Stream.empty();

  @override
  Future<bool> checkRemoteTextInputReady({required TvDevice device}) async =>
      false;

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      RemoteCommand.values.toSet();

  @override
  Stream<remote_connection.ConnectionState> watchConnectionState({
    required TvDevice device,
  }) => const Stream.empty();

  @override
  Future<void> connect({required TvDevice device}) async {}

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;
}

class _SlowCommandService implements RemoteCommandService {
  @override
  Future<CommandDispatchResult> preparePairing({required TvDevice device}) =>
      Completer<CommandDispatchResult>().future;

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async => CommandDispatchResult.unsupported('unused');

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<void> cancelPairing({required TvDevice device}) async {}

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async => CommandDispatchResult.unsupported('unused');

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async => CommandDispatchResult.unsupported('unused');

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      const Stream.empty();

  @override
  Future<bool> checkRemoteTextInputReady({required TvDevice device}) async =>
      false;

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      RemoteCommand.values.toSet();

  @override
  Stream<remote_connection.ConnectionState> watchConnectionState({
    required TvDevice device,
  }) => const Stream.empty();

  @override
  Future<void> connect({required TvDevice device}) async {}

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;
}

class _StubDiscoveryService implements DeviceDiscoveryService {
  @override
  Future<List<TvDevice>> discoverDevices() async => [lgDevice, hisenseDevice];
}

class _CountingDiscoveryService extends _StubDiscoveryService {
  int callCount = 0;

  @override
  Future<List<TvDevice>> discoverDevices() async {
    callCount++;
    return super.discoverDevices();
  }
}

class _SlowDiscoveryService implements DeviceDiscoveryService {
  @override
  Future<List<TvDevice>> discoverDevices() =>
      Completer<List<TvDevice>>().future;
}

const lgDevice = TvDevice(
  id: 'lg-192.168.1.10',
  displayName: 'LG TV',
  brand: TvBrand.lg,
  capabilities: {DeviceCapability.keyCommands},
);

const hisenseDevice = TvDevice(
  id: 'hisense-192.168.1.20',
  displayName: 'Hisense TV',
  brand: TvBrand.hisense,
  capabilities: {DeviceCapability.keyCommands, DeviceCapability.pinPairing},
);

class _StubDeviceRepository implements DeviceRepository {
  _StubDeviceRepository({this.savedDevices = const []});
  final List<TvDevice> savedDevices;

  @override
  Future<void> saveDevice(TvDevice device) async {}
  @override
  Future<List<TvDevice>> getSavedDevices() async => savedDevices;
  @override
  Future<TvDevice?> getLastUsedDevice() async => null;
  @override
  Future<List<String>> getRecentManualIps() async => [];
  @override
  Future<DateTime?> getLastSuccessfulPairingAt(String deviceId) async => null;
  @override
  Future<void> removeSavedDevice(String deviceId) async {}
  @override
  Future<void> saveRecentManualIp(String ipAddress) async {}
  @override
  Future<void> setLastSuccessfulPairingAt({
    required String deviceId,
    required DateTime timestamp,
  }) async {}
  @override
  Future<void> setLastUsedDevice(String deviceId) async {}
  @override
  Future<void> saveDeviceSystemInfo(
    String deviceId,
    Map<String, dynamic> info,
  ) async {}
  @override
  Future<Map<String, dynamic>?> getDeviceSystemInfo(String deviceId) async =>
      null;
}

class _SpyDeviceRepository extends _StubDeviceRepository {
  _SpyDeviceRepository({super.savedDevices});
  TvDevice? lastSavedDevice;
  int setLastUsedDeviceCallCount = 0;

  @override
  Future<void> saveDevice(TvDevice device) async {
    lastSavedDevice = device;
  }

  @override
  Future<void> setLastUsedDevice(String deviceId) async {
    setLastUsedDeviceCallCount++;
  }
}

class _MutableSpyDeviceRepository extends _SpyDeviceRepository {
  _MutableSpyDeviceRepository({required super.savedDevices})
    : _devices = List<TvDevice>.from(savedDevices);

  final List<TvDevice> _devices;
  final List<String> removedDeviceIds = [];

  @override
  Future<List<TvDevice>> getSavedDevices() async =>
      List<TvDevice>.unmodifiable(_devices);

  @override
  Future<void> removeSavedDevice(String deviceId) async {
    removedDeviceIds.add(deviceId);
    _devices.removeWhere((device) => device.id == deviceId);
  }
}

class _StubTvReachabilityService implements TvReachabilityService {
  const _StubTvReachabilityService({this.reachable = false});
  final bool reachable;
  @override
  Future<bool> isReachable(TvDevice device) async => reachable;
}

class _NeverResolvingReachabilityService implements TvReachabilityService {
  @override
  Future<bool> isReachable(TvDevice device) => Completer<bool>().future;
}

class _SpyTvReachabilityService implements TvReachabilityService {
  final List<String> probedDeviceIds = [];
  @override
  Future<bool> isReachable(TvDevice device) async {
    probedDeviceIds.add(device.id);
    return false;
  }
}

class _StubPrePairingStepsRegistry implements PrePairingStepsRegistry {
  const _StubPrePairingStepsRegistry({this.steps});
  final List<String>? steps;

  @override
  List<String>? stepsFor(TvBrand brand, String protocolVariant) => steps;
}

class _StubPairingProgressHintRegistry implements PairingProgressHintRegistry {
  const _StubPairingProgressHintRegistry({this.hint});
  final String? hint;

  @override
  String? hintFor(TvBrand brand, String protocolVariant) => hint;
}
