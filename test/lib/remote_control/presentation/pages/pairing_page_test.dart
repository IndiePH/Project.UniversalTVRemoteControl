import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page.dart';

void main() {
  Widget buildPage({
    required RemoteCommandService commandService,
    _StubPrePairingStepsRegistry? stepsRegistry,
    _StubPairingProgressHintRegistry? hintRegistry,
  }) {
    return MaterialApp(
      home: PairingPage(
        commandService: commandService,
        discoveryService: _StubDiscoveryService(),
        deviceRepository: _StubDeviceRepository(),
        stepsRegistry: stepsRegistry ?? _StubPrePairingStepsRegistry(),
        hintRegistry: hintRegistry ?? _StubPairingProgressHintRegistry(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Outcome dialog — success
  // ---------------------------------------------------------------------------

  group('outcome dialog on success', () {
    testWidgets('shows success dialog after successful pairing', (tester) async {
      await tester.pumpWidget(buildPage(
        commandService: _StubCommandService(
          preparePairingResult: CommandDispatchResult.success('OK'),
        ),
        stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
      ));
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
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedDevice = await Navigator.of(context).push<TvDevice>(
                  MaterialPageRoute(
                    builder: (_) => PairingPage(
                      commandService: _StubCommandService(
                        preparePairingResult: CommandDispatchResult.success('OK'),
                      ),
                      discoveryService: _StubDiscoveryService(),
                      deviceRepository: _StubDeviceRepository(),
                      stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
                      hintRegistry: _StubPairingProgressHintRegistry(),
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
      await tester.pumpWidget(buildPage(
        commandService: _StubCommandService(
          preparePairingResult: CommandDispatchResult.failure('Connection refused'),
        ),
        stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
      ));
      await tester.pump();

      await tester.tap(find.text('LG TV'));
      await tester.pumpAndSettle();

      expect(find.text('Pairing failed'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('stays on pairing page after tapping Dismiss on failure',
        (tester) async {
      await tester.pumpWidget(buildPage(
        commandService: _StubCommandService(
          preparePairingResult: CommandDispatchResult.failure('Connection refused'),
        ),
        stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
      ));
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
    testWidgets('shows hint from registry while pairing is in progress',
        (tester) async {
      const hint = 'Look at your TV screen.';
      await tester.pumpWidget(buildPage(
        commandService: _SlowCommandService(),
        stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
        hintRegistry: _StubPairingProgressHintRegistry(hint: hint),
      ));
      await tester.pump();

      await tester.tap(find.text('LG TV'));
      await tester.pump();

      expect(find.text(hint), findsOneWidget);
    });

    testWidgets('shows no hint when registry returns null for brand',
        (tester) async {
      await tester.pumpWidget(buildPage(
        commandService: _SlowCommandService(),
        stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
        hintRegistry: _StubPairingProgressHintRegistry(hint: null),
      ));
      await tester.pump();

      await tester.tap(find.text('LG TV'));
      await tester.pump();

      expect(find.text('Look at your TV screen and accept the pairing prompt.'),
          findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // PIN flow regression
  // ---------------------------------------------------------------------------

  group('pin flow regression', () {
    testWidgets('prompts for PIN and shows success dialog after correct PIN',
        (tester) async {
      await tester.pumpWidget(buildPage(
        commandService: _StubCommandService(
          preparePairingResult: CommandDispatchResult.failure('Needs PIN'),
          submitPairingResults: [CommandDispatchResult.success('OK')],
        ),
        stepsRegistry: _StubPrePairingStepsRegistry(steps: null),
      ));
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
  });
}

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _StubCommandService implements RemoteCommandService {
  _StubCommandService({
    required this.preparePairingResult,
    this.submitPairingResults = const [],
  });

  final CommandDispatchResult preparePairingResult;
  final List<CommandDispatchResult> submitPairingResults;
  int _submitIndex = 0;

  @override
  Future<CommandDispatchResult> preparePairing({required TvDevice device}) async =>
      preparePairingResult;

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    if (submitPairingResults.isEmpty) return CommandDispatchResult.success('OK');
    final i = _submitIndex.clamp(0, submitPairingResults.length - 1);
    _submitIndex++;
    return submitPairingResults[i];
  }

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async =>
      CommandDispatchResult.unsupported('unused');

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async =>
      CommandDispatchResult.unsupported('unused');

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      const Stream.empty();
}

class _SlowCommandService implements RemoteCommandService {
  @override
  Future<CommandDispatchResult> preparePairing({required TvDevice device}) =>
      Completer<CommandDispatchResult>().future;

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async =>
      CommandDispatchResult.unsupported('unused');

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async =>
      CommandDispatchResult.unsupported('unused');

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async =>
      CommandDispatchResult.unsupported('unused');

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      const Stream.empty();
}

class _StubDiscoveryService implements DeviceDiscoveryService {
  @override
  Future<List<TvDevice>> discoverDevices() async => [lgDevice, hisenseDevice];
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
  @override
  Future<void> saveDevice(TvDevice device) async {}
  @override
  Future<List<TvDevice>> getSavedDevices() async => [];
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
  Future<void> saveDeviceSystemInfo(String deviceId, Map<String, dynamic> info) async {}
  @override
  Future<Map<String, dynamic>?> getDeviceSystemInfo(String deviceId) async => null;
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
