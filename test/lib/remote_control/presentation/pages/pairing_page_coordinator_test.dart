import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_coordinator.dart';

void main() {
  const pinPairingDevice = TvDevice(
    id: 'hisense-1',
    displayName: 'Hisense TV',
    brand: TvBrand.hisense,
    capabilities: {DeviceCapability.keyCommands, DeviceCapability.pinPairing},
  );

  const nonPinDevice = TvDevice(
    id: 'samsung-1',
    displayName: 'Samsung TV',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands},
  );

  // ---------------------------------------------------------------------------
  // _attemptPinPairing
  // ---------------------------------------------------------------------------

  group('_attemptPinPairing', () {
    test(
      'returns success when pin provided and submitPairingCode succeeds',
      () async {
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.failure('Needs PIN'),
          submitPairingResults: [CommandDispatchResult.success('OK')],
        );

        final result = await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_) async => '1234',
          onPinRejected: (_) {},
        );

        expect(result.isSuccess, isTrue);
      },
    );

    test('returns failure when user cancels pin prompt', () async {
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.failure('Needs PIN'),
      );

      final result = await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_) async => null,
        onPinRejected: (_) {},
      );

      expect(result.isSuccess, isFalse);
    });

    test(
      'retries loop after rejected pin and succeeds on next attempt',
      () async {
        var promptCallCount = 0;
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.failure('Needs PIN'),
          submitPairingResults: [
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.success('OK'),
          ],
        );

        final result = await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_) async {
            promptCallCount++;
            return '1234';
          },
          onPinRejected: (_) {},
        );

        expect(result.isSuccess, isTrue);
        expect(promptCallCount, 2);
      },
    );

    test('cancels after rejection when user returns null on retry', () async {
      var promptCallCount = 0;
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.failure('Needs PIN'),
        submitPairingResults: [CommandDispatchResult.failure('Wrong PIN')],
      );

      final result = await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_) async => ++promptCallCount == 1 ? '0000' : null,
        onPinRejected: (_) {},
      );

      expect(result.isSuccess, isFalse);
    });

    test(
      'calls onPinRejected with failure message when pin is wrong',
      () async {
        const rejectionMessage = 'Wrong PIN';
        var promptCallCount = 0;
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.failure('Needs PIN'),
          submitPairingResults: [
            CommandDispatchResult.failure(rejectionMessage),
            CommandDispatchResult.success('OK'),
          ],
        );

        final rejectedMessages = <String>[];
        await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_) async => ++promptCallCount <= 2 ? '0000' : null,
          onPinRejected: rejectedMessages.add,
        );

        expect(rejectedMessages, [rejectionMessage]);
      },
    );

    test(
      'does not attempt pin pairing when device lacks pinPairing capability',
      () async {
        var promptCalled = false;
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.failure('Pairing failed'),
        );

        final result = await coordinator.pairSelectedDevice(
          device: nonPinDevice,
          promptPin: (_) async {
            promptCalled = true;
            return '1234';
          },
          onPinRejected: (_) {},
        );

        expect(result.isSuccess, isFalse);
        expect(promptCalled, isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Device persistence
  // ---------------------------------------------------------------------------

  group('device persistence', () {
    test('saves device after successful pin pairing', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.failure('Needs PIN'),
        submitPairingResults: [CommandDispatchResult.success('OK')],
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_) async => '1234',
        onPinRejected: (_) {},
      );

      expect(repo.saveDeviceCallCount, 1);
    });

    test('does not save device when pin pairing is cancelled', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.failure('Needs PIN'),
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_) async => null,
        onPinRejected: (_) {},
      );

      expect(repo.saveDeviceCallCount, 0);
    });
  });
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

PairingPageCoordinator _makeCoordinator({
  required CommandDispatchResult preparePairingResult,
  List<CommandDispatchResult> submitPairingResults = const [],
  _StubDeviceRepository? deviceRepository,
}) {
  return PairingPageCoordinator(
    commandService: _StubCommandService(
      preparePairingResult: preparePairingResult,
      submitPairingResults: submitPairingResults,
    ),
    deviceRepository: deviceRepository ?? _StubDeviceRepository(),
  );
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
  int _submitCallIndex = 0;

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async => preparePairingResult;

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    if (submitPairingResults.isEmpty) {
      return CommandDispatchResult.success('OK');
    }
    final index = _submitCallIndex.clamp(0, submitPairingResults.length - 1);
    _submitCallIndex++;
    return submitPairingResults[index];
  }

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async => CommandDispatchResult.unsupported('not used in this test');

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async => CommandDispatchResult.unsupported('not used in this test');

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      const Stream.empty();

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      RemoteCommand.values.toSet();

  @override
  Stream<ConnectionState> watchConnectionState({required TvDevice device}) =>
      const Stream.empty();
}

class _StubDeviceRepository implements DeviceRepository {
  int saveDeviceCallCount = 0;

  @override
  Future<void> saveDevice(TvDevice device) async => saveDeviceCallCount++;

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
  Future<void> saveDeviceSystemInfo(
    String deviceId,
    Map<String, dynamic> info,
  ) async {}

  @override
  Future<Map<String, dynamic>?> getDeviceSystemInfo(String deviceId) async =>
      null;
}
