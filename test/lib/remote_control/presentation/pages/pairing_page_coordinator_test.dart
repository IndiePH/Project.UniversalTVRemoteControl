import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import 'package:one_remote/remote_control/domain/models/pin_format.dart';
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
          preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
          submitPairingResults: [CommandDispatchResult.success('OK')],
        );

        final result = await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, _) async => '1234',
          onPinRejected: (_) {},
        );

        expect(result.isSuccess, isTrue);
      },
    );

    test('returns failure when user cancels pin prompt', () async {
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
      );

      final result = await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_, _) async => null,
        onPinRejected: (_) {},
      );

      expect(result.isSuccess, isFalse);
    });

    test(
      'retries loop after rejected pin and succeeds on next attempt',
      () async {
        var promptCallCount = 0;
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
          submitPairingResults: [
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.success('OK'),
          ],
        );

        final result = await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, _) async {
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
        preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
        submitPairingResults: [CommandDispatchResult.failure('Wrong PIN')],
      );

      final result = await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_, _) async => ++promptCallCount == 1 ? '0000' : null,
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
          preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
          submitPairingResults: [
            CommandDispatchResult.failure(rejectionMessage),
            CommandDispatchResult.success('OK'),
          ],
        );

        final rejectedMessages = <String>[];
        await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, _) async => ++promptCallCount <= 2 ? '0000' : null,
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
          promptPin: (_, _) async {
            promptCalled = true;
            return '1234';
          },
          onPinRejected: (_) {},
        );

        expect(result.isSuccess, isFalse);
        expect(promptCalled, isFalse);
      },
    );

    test('promptPin receives PinFormat from pinRequired result', () async {
      PinFormat? capturedFormat;
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.pinRequired(
          'Enter code',
          pinFormat: PinFormat.sixCharHex,
        ),
        submitPairingResults: [CommandDispatchResult.success('OK')],
      );

      await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_, format) async {
          capturedFormat = format;
          return 'ABCDEF';
        },
        onPinRejected: (_) {},
      );

      expect(capturedFormat, PinFormat.sixCharHex);
    });

    test(
      'PinFormat.sixCharHex is forwarded to promptPin when result carries it',
      () async {
        PinFormat? receivedFormat;
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.pinRequired(
            'Enter hex code',
            pinFormat: PinFormat.sixCharHex,
          ),
          submitPairingResults: [CommandDispatchResult.success('OK')],
        );

        await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, format) async {
            receivedFormat = format;
            return 'A1B2C3';
          },
          onPinRejected: (_) {},
        );

        expect(receivedFormat, PinFormat.sixCharHex);
      },
    );

    test(
      'cancelling promptPin dialog results in PairingAttemptResult.failure',
      () async {
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
        );

        final result = await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, _) async => null,
          onPinRejected: (_) {},
        );

        expect(result.isSuccess, isFalse);
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
        preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
        submitPairingResults: [CommandDispatchResult.success('OK')],
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(repo.saveDeviceCallCount, 1);
    });

    test('does not save device when pin pairing is cancelled', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_, _) async => null,
        onPinRejected: (_) {},
      );

      expect(repo.saveDeviceCallCount, 0);
    });

    test(
      'does not setLastUsedDevice or setLastSuccessfulPairingAt when pin pairing cancelled',
      () async {
        final repo = _StubDeviceRepository();
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
          deviceRepository: repo,
        );

        await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, _) async => null,
          onPinRejected: (_) {},
        );

        expect(repo.setLastUsedDeviceCallCount, 0);
        expect(repo.setLastSuccessfulPairingAtCallCount, 0);
      },
    );

    test('records full persistence side effects on PIN success', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
        submitPairingResults: [CommandDispatchResult.success('OK')],
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(repo.saveDeviceCallCount, 1);
      expect(repo.setLastUsedDeviceCallCount, 1);
      expect(repo.lastUsedDeviceId, pinPairingDevice.id);
      expect(repo.setLastSuccessfulPairingAtCallCount, 1);
      expect(repo.lastSuccessfulPairingDeviceId, pinPairingDevice.id);
      expect(repo.lastSuccessfulPairingTimestamp, isA<DateTime>());
    });

    test('persists manualIpToSave on PIN success when provided', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
        submitPairingResults: [CommandDispatchResult.success('OK')],
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        manualIpToSave: '192.168.1.42',
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(repo.saveRecentManualIpCallCount, 1);
      expect(repo.lastSavedManualIp, '192.168.1.42');
    });
  });

  // ---------------------------------------------------------------------------
  // Non-PIN success paths
  // ---------------------------------------------------------------------------

  group('pairSelectedDevice — non-PIN success', () {
    test('returns success result when preparePairing succeeds', () async {
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.success('Approved'),
      );

      final result = await coordinator.pairSelectedDevice(
        device: nonPinDevice,
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(result.isSuccess, isTrue);
    });

    test('does not invoke promptPin for non-PIN devices', () async {
      var promptCalled = false;
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.success('Approved'),
      );

      await coordinator.pairSelectedDevice(
        device: nonPinDevice,
        promptPin: (_, _) async {
          promptCalled = true;
          return '1234';
        },
        onPinRejected: (_) {},
      );

      expect(promptCalled, isFalse);
    });

    test('does not invoke submitPairingCode for non-PIN devices', () async {
      final commandService = _StubCommandService(
        preparePairingResult: CommandDispatchResult.success('Approved'),
      );
      final coordinator = PairingPageCoordinator(
        commandService: commandService,
        deviceRepository: _StubDeviceRepository(),
      );

      await coordinator.pairSelectedDevice(
        device: nonPinDevice,
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(commandService.submitCallCount, 0);
    });

    test(
      'records full persistence side effects when preparePairing succeeds',
      () async {
        final repo = _StubDeviceRepository();
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.success('Approved'),
          deviceRepository: repo,
        );

        await coordinator.pairSelectedDevice(
          device: nonPinDevice,
          promptPin: (_, _) async => '1234',
          onPinRejected: (_) {},
        );

        expect(repo.saveDeviceCallCount, 1);
        expect(repo.setLastUsedDeviceCallCount, 1);
        expect(repo.lastUsedDeviceId, nonPinDevice.id);
        expect(repo.setLastSuccessfulPairingAtCallCount, 1);
        expect(repo.lastSuccessfulPairingDeviceId, nonPinDevice.id);
      },
    );

    test('persists manualIpToSave when provided on success', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.success('Approved'),
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: nonPinDevice,
        manualIpToSave: '192.168.1.50',
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(repo.saveRecentManualIpCallCount, 1);
      expect(repo.lastSavedManualIp, '192.168.1.50');
    });

    test('skips saveRecentManualIp when manualIpToSave is null', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.success('Approved'),
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: nonPinDevice,
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(repo.saveRecentManualIpCallCount, 0);
    });

    test('skips saveRecentManualIp when manualIpToSave is empty', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.success('Approved'),
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: nonPinDevice,
        manualIpToSave: '',
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(repo.saveRecentManualIpCallCount, 0);
    });

    test(
      'saves enriched device from preparePairing result when present',
      () async {
        final repo = _StubDeviceRepository();
        const enriched = TvDevice(
          id: 'samsung-1',
          displayName: 'Samsung TV (Enriched)',
          brand: TvBrand.samsung,
          capabilities: {
            DeviceCapability.keyCommands,
            DeviceCapability.textInput,
          },
          modelIdentifier: 'UN65',
        );
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.success(
            'Approved',
            device: enriched,
          ),
          deviceRepository: repo,
        );

        await coordinator.pairSelectedDevice(
          device: nonPinDevice,
          promptPin: (_, _) async => '1234',
          onPinRejected: (_) {},
        );

        expect(repo.lastSavedDevice, same(enriched));
        expect(repo.lastSavedDevice?.modelIdentifier, 'UN65');
      },
    );

    test(
      'falls back to input device when preparePairing result has no device',
      () async {
        final repo = _StubDeviceRepository();
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.success('Approved'),
          deviceRepository: repo,
        );

        await coordinator.pairSelectedDevice(
          device: nonPinDevice,
          promptPin: (_, _) async => '1234',
          onPinRejected: (_) {},
        );

        expect(repo.lastSavedDevice, same(nonPinDevice));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Non-PIN failure paths
  // ---------------------------------------------------------------------------

  group('pairSelectedDevice — non-PIN failure', () {
    test('returns failure result when preparePairing fails', () async {
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.failure(
          'Connection refused',
        ),
      );

      final result = await coordinator.pairSelectedDevice(
        device: nonPinDevice,
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(result.isSuccess, isFalse);
    });

    test(
      'failure result message reflects sanitized prepare result message',
      () async {
        const failureMessage = 'Pairing handshake refused by TV';
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.failure(failureMessage),
        );

        final result = await coordinator.pairSelectedDevice(
          device: nonPinDevice,
          promptPin: (_, _) async => '1234',
          onPinRejected: (_) {},
        );

        expect(result.message, failureMessage);
      },
    );

    test('does not save device on failure', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.failure(
          'Connection refused',
        ),
        deviceRepository: repo,
      );

      await coordinator.pairSelectedDevice(
        device: nonPinDevice,
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(repo.saveDeviceCallCount, 0);
    });

    test(
      'does not record last-used or last-successful-at on failure',
      () async {
        final repo = _StubDeviceRepository();
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.failure(
            'Connection refused',
          ),
          deviceRepository: repo,
        );

        await coordinator.pairSelectedDevice(
          device: nonPinDevice,
          promptPin: (_, _) async => '1234',
          onPinRejected: (_) {},
        );

        expect(repo.setLastUsedDeviceCallCount, 0);
        expect(repo.setLastSuccessfulPairingAtCallCount, 0);
      },
    );

    test(
      'does not persist manualIpToSave on failure even when provided',
      () async {
        final repo = _StubDeviceRepository();
        final coordinator = _makeCoordinator(
          preparePairingResult: CommandDispatchResult.failure(
            'Connection refused',
          ),
          deviceRepository: repo,
        );

        await coordinator.pairSelectedDevice(
          device: nonPinDevice,
          manualIpToSave: '192.168.1.50',
          promptPin: (_, _) async => '1234',
          onPinRejected: (_) {},
        );

        expect(repo.saveRecentManualIpCallCount, 0);
      },
    );

    test(
      'does not invoke submitPairingCode when preparePairing fails outright',
      () async {
        final commandService = _StubCommandService(
          preparePairingResult: CommandDispatchResult.failure('Refused'),
        );
        final coordinator = PairingPageCoordinator(
          commandService: commandService,
          deviceRepository: _StubDeviceRepository(),
        );

        await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, _) async => '1234',
          onPinRejected: (_) {},
        );

        expect(commandService.submitCallCount, 0);
      },
    );

    test('unsupported preparePairing result is treated as failure', () async {
      final repo = _StubDeviceRepository();
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.unsupported(
          'No adapter for samsung',
        ),
        deviceRepository: repo,
      );

      final result = await coordinator.pairSelectedDevice(
        device: nonPinDevice,
        promptPin: (_, _) async => '1234',
        onPinRejected: (_) {},
      );

      expect(result.isSuccess, isFalse);
      expect(repo.saveDeviceCallCount, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // PIN retry depth
  // ---------------------------------------------------------------------------

  group('pairSelectedDevice — PIN retry depth', () {
    test(
      'loops through 3 rejections before final success on 4th attempt',
      () async {
        var promptCallCount = 0;
        final commandService = _StubCommandService(
          preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
          submitPairingResults: [
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.success('OK'),
          ],
        );
        final coordinator = PairingPageCoordinator(
          commandService: commandService,
          deviceRepository: _StubDeviceRepository(),
        );

        final rejections = <String>[];
        final result = await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, _) async {
            promptCallCount++;
            return '1234';
          },
          onPinRejected: rejections.add,
        );

        expect(result.isSuccess, isTrue);
        expect(promptCallCount, 4);
        expect(commandService.submitCallCount, 4);
        expect(rejections, hasLength(3));
      },
    );

    test(
      'cancels with failure after long rejection chain when user gives up',
      () async {
        var promptCallCount = 0;
        final commandService = _StubCommandService(
          preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
          submitPairingResults: [
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.failure('Wrong PIN'),
          ],
        );
        final repo = _StubDeviceRepository();
        final coordinator = PairingPageCoordinator(
          commandService: commandService,
          deviceRepository: repo,
        );

        final result = await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, _) async {
            promptCallCount++;
            return promptCallCount <= 5 ? '0000' : null;
          },
          onPinRejected: (_) {},
        );

        expect(result.isSuccess, isFalse);
        expect(promptCallCount, 6);
        expect(commandService.submitCallCount, 5);
        expect(repo.saveDeviceCallCount, 0);
      },
    );

    test(
      'forwards entered PIN verbatim across retries (no mutation)',
      () async {
        var promptCallCount = 0;
        final commandService = _StubCommandService(
          preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
          submitPairingResults: [
            CommandDispatchResult.failure('Wrong PIN'),
            CommandDispatchResult.success('OK'),
          ],
        );
        final coordinator = PairingPageCoordinator(
          commandService: commandService,
          deviceRepository: _StubDeviceRepository(),
        );

        await coordinator.pairSelectedDevice(
          device: pinPairingDevice,
          promptPin: (_, _) async {
            promptCallCount++;
            return promptCallCount == 1 ? '0000' : 'A1B2C3';
          },
          onPinRejected: (_) {},
        );

        expect(commandService.submittedPins, ['0000', 'A1B2C3']);
      },
    );

    test('invokes onPinRejected once per rejected submit attempt', () async {
      final coordinator = _makeCoordinator(
        preparePairingResult: CommandDispatchResult.pinRequired('Needs PIN'),
        submitPairingResults: [
          CommandDispatchResult.failure('Wrong 1'),
          CommandDispatchResult.failure('Wrong 2'),
          CommandDispatchResult.failure('Wrong 3'),
          CommandDispatchResult.success('OK'),
        ],
      );

      final rejections = <String>[];
      await coordinator.pairSelectedDevice(
        device: pinPairingDevice,
        promptPin: (_, _) async => '1234',
        onPinRejected: rejections.add,
      );

      expect(rejections, ['Wrong 1', 'Wrong 2', 'Wrong 3']);
    });
  });

  // ---------------------------------------------------------------------------
  // cancelPairing delegation
  // ---------------------------------------------------------------------------

  group('cancelPairing', () {
    test(
      'delegates to commandService.cancelPairing with the same device',
      () async {
        final commandService = _StubCommandService(
          preparePairingResult: CommandDispatchResult.success('OK'),
        );
        final coordinator = PairingPageCoordinator(
          commandService: commandService,
          deviceRepository: _StubDeviceRepository(),
        );

        await coordinator.cancelPairing(device: pinPairingDevice);

        expect(commandService.cancelPairingCallCount, 1);
        expect(commandService.lastCancelledDevice, same(pinPairingDevice));
      },
    );
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

  int submitCallCount = 0;
  int cancelPairingCallCount = 0;
  TvDevice? lastCancelledDevice;
  final List<String> submittedPins = [];

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async => preparePairingResult;

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async {
    submitCallCount++;
    submittedPins.add(pinCode);
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
  Future<void> cancelPairing({required TvDevice device}) async {
    cancelPairingCallCount++;
    lastCancelledDevice = device;
  }

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
  Future<bool> checkRemoteTextInputReady({required TvDevice device}) async =>
      false;

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      RemoteCommand.values.toSet();

  @override
  Stream<ConnectionState> watchConnectionState({required TvDevice device}) =>
      const Stream.empty();

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;
}

class _StubDeviceRepository implements DeviceRepository {
  int saveDeviceCallCount = 0;
  int setLastUsedDeviceCallCount = 0;
  int setLastSuccessfulPairingAtCallCount = 0;
  int saveRecentManualIpCallCount = 0;

  TvDevice? lastSavedDevice;
  String? lastUsedDeviceId;
  String? lastSuccessfulPairingDeviceId;
  DateTime? lastSuccessfulPairingTimestamp;
  String? lastSavedManualIp;

  @override
  Future<void> saveDevice(TvDevice device) async {
    saveDeviceCallCount++;
    lastSavedDevice = device;
  }

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
  Future<void> saveRecentManualIp(String ipAddress) async {
    saveRecentManualIpCallCount++;
    lastSavedManualIp = ipAddress;
  }

  @override
  Future<void> setLastSuccessfulPairingAt({
    required String deviceId,
    required DateTime timestamp,
  }) async {
    setLastSuccessfulPairingAtCallCount++;
    lastSuccessfulPairingDeviceId = deviceId;
    lastSuccessfulPairingTimestamp = timestamp;
  }

  @override
  Future<void> setLastUsedDevice(String deviceId) async {
    setLastUsedDeviceCallCount++;
    lastUsedDeviceId = deviceId;
  }

  @override
  Future<void> saveDeviceSystemInfo(
    String deviceId,
    Map<String, dynamic> info,
  ) async {}

  @override
  Future<Map<String, dynamic>?> getDeviceSystemInfo(String deviceId) async =>
      null;
}
