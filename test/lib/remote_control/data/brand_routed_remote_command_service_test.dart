import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  const device = TvDevice(
    id: 'test-id',
    displayName: 'Test TV',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands, DeviceCapability.textInput},
  );

  const lgDevice = TvDevice(
    id: 'lg-1',
    displayName: 'LG TV',
    brand: TvBrand.lg,
    capabilities: {DeviceCapability.keyCommands, DeviceCapability.textInput},
  );

  const deviceNoTextInput = TvDevice(
    id: 'samsung-no-text',
    displayName: 'Samsung TV',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands},
  );

  // 2.12 — Strategy map routing: verify each method dispatches to the correct
  // brand adapter and short-circuits when no adapter is configured.

  group('brand dispatch — preparePairing', () {
    test('routes to the matching brand adapter', () async {
      final samsung = _RecordingAdapter(brand: TvBrand.samsung);
      final lg = _RecordingAdapter(brand: TvBrand.lg);
      final service = BrandRoutedRemoteCommandService(adapters: [samsung, lg]);

      await service.preparePairing(device: device);

      expect(samsung.preparePairingCallCount, 1);
      expect(lg.preparePairingCallCount, 0);
    });

    test('returns unsupported when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(adapters: []);
      final result = await service.preparePairing(device: device);
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('samsung'));
    });

    test('returns success when adapter succeeds', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_RecordingAdapter(brand: TvBrand.samsung)],
      );
      final result = await service.preparePairing(device: device);
      expect(result.isSuccess, isTrue);
    });
  });

  group('brand dispatch — submitPairingCode', () {
    test('routes to the matching brand adapter', () async {
      final samsung = _RecordingAdapter(brand: TvBrand.samsung);
      final lg = _RecordingAdapter(brand: TvBrand.lg);
      final service = BrandRoutedRemoteCommandService(adapters: [samsung, lg]);

      await service.submitPairingCode(device: device, fourDigitPin: '1234');

      expect(samsung.submitPairingCodeCallCount, 1);
      expect(lg.submitPairingCodeCallCount, 0);
    });

    test('returns unsupported when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(adapters: []);
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '0000',
      );
      expect(result.isSuccess, isFalse);
    });

    test('returns success when adapter succeeds', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_RecordingAdapter(brand: TvBrand.samsung)],
      );
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '1234',
      );
      expect(result.isSuccess, isTrue);
    });
  });

  group('brand dispatch — sendCommand', () {
    test('routes to the matching brand adapter', () async {
      final samsung = _RecordingAdapter(brand: TvBrand.samsung);
      final lg = _RecordingAdapter(brand: TvBrand.lg);
      final service = BrandRoutedRemoteCommandService(adapters: [samsung, lg]);

      await service.sendCommand(device: device, command: RemoteCommand.volumeUp);

      expect(samsung.sendCommandCallCount, 1);
      expect(lg.sendCommandCallCount, 0);
    });

    test('returns unsupported when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(adapters: []);
      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );
      expect(result.isSuccess, isFalse);
    });

    test('returns unsupported and skips adapter when command not supported', () async {
      final adapter = _RecordingAdapter(
        brand: TvBrand.samsung,
        supportedCommands: {},
      );
      final service = BrandRoutedRemoteCommandService(adapters: [adapter]);

      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );

      expect(result.isSuccess, isFalse);
      expect(adapter.sendCommandCallCount, 0);
    });

    test('returns success when adapter succeeds', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_RecordingAdapter(brand: TvBrand.samsung)],
      );
      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );
      expect(result.isSuccess, isTrue);
    });
  });

  group('brand dispatch — sendText', () {
    test('routes to the matching brand adapter', () async {
      final samsung = _RecordingAdapter(brand: TvBrand.samsung);
      final lg = _RecordingAdapter(brand: TvBrand.lg);
      final service = BrandRoutedRemoteCommandService(adapters: [samsung, lg]);

      await service.sendText(device: device, text: 'hello');

      expect(samsung.sendTextCallCount, 1);
      expect(lg.sendTextCallCount, 0);
    });

    test('returns unsupported when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(adapters: []);
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.isSuccess, isFalse);
    });

    test('returns unsupported and skips adapter when text input not supported', () async {
      final adapter = _RecordingAdapter(
        brand: TvBrand.samsung,
        supportsTextInput: false,
      );
      final service = BrandRoutedRemoteCommandService(adapters: [adapter]);

      final result = await service.sendText(device: device, text: 'hello');

      expect(result.isSuccess, isFalse);
      expect(adapter.sendTextCallCount, 0);
    });

    test('returns success when adapter succeeds', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_RecordingAdapter(brand: TvBrand.samsung)],
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.isSuccess, isTrue);
    });
  });

  group('brand dispatch — watchRemoteTextInputReady', () {
    test('returns false stream when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(adapters: []);
      final result = await service
          .watchRemoteTextInputReady(device: device)
          .first;
      expect(result, isFalse);
    });

    test('returns false stream when adapter does not support text input', () async {
      final adapter = _RecordingAdapter(
        brand: TvBrand.samsung,
        supportsTextInput: false,
      );
      final service = BrandRoutedRemoteCommandService(adapters: [adapter]);
      final result = await service
          .watchRemoteTextInputReady(device: device)
          .first;
      expect(result, isFalse);
    });

    test('returns false stream when device lacks textInput capability', () async {
      final adapter = _RecordingAdapter(brand: TvBrand.samsung);
      final service = BrandRoutedRemoteCommandService(adapters: [adapter]);
      final result = await service
          .watchRemoteTextInputReady(device: deviceNoTextInput)
          .first;
      expect(result, isFalse);
    });

    test('delegates to adapter stream when all conditions are met', () async {
      final adapter = _RecordingAdapter(
        brand: TvBrand.samsung,
        textInputReadyStream: Stream.value(true),
      );
      final service = BrandRoutedRemoteCommandService(adapters: [adapter]);
      final result = await service
          .watchRemoteTextInputReady(device: device)
          .first;
      expect(result, isTrue);
    });

    test('routes to matching brand adapter, not others', () async {
      final samsung = _RecordingAdapter(
        brand: TvBrand.samsung,
        textInputReadyStream: Stream.value(true),
      );
      final lg = _RecordingAdapter(
        brand: TvBrand.lg,
        textInputReadyStream: Stream.value(false),
      );
      final service = BrandRoutedRemoteCommandService(adapters: [samsung, lg]);
      final result = await service
          .watchRemoteTextInputReady(device: device)
          .first;
      expect(result, isTrue);
    });

    test('lg device routes to lg adapter stream', () async {
      final samsung = _RecordingAdapter(
        brand: TvBrand.samsung,
        textInputReadyStream: Stream.value(false),
      );
      final lg = _RecordingAdapter(
        brand: TvBrand.lg,
        textInputReadyStream: Stream.value(true),
      );
      final service = BrandRoutedRemoteCommandService(adapters: [samsung, lg]);
      final result = await service
          .watchRemoteTextInputReady(device: lgDevice)
          .first;
      expect(result, isTrue);
    });
  });

  // 2.17: generic catch blocks always return a safe message and carry the raw
  // exception so env-aware consumers can surface detail in non-production builds.

  group('preparePairing — unexpected failure', () {
    test('returns failure outcome', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.preparePairing(device: device);
      expect(result.isSuccess, isFalse);
      expect(result.outcome, CommandOutcome.failure);
    });

    test('message is always generic', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.preparePairing(device: device);
      expect(result.message, 'Something went wrong.');
    });

    test('exception carries the raw error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.preparePairing(device: device);
      expect(result.exception, isA<StateError>());
      expect((result.exception as StateError).message, 'pairing error');
    });
  });

  group('submitPairingCode — unexpected failure', () {
    test('returns failure outcome', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '1234',
      );
      expect(result.isSuccess, isFalse);
      expect(result.outcome, CommandOutcome.failure);
    });

    test('message is always generic', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '1234',
      );
      expect(result.message, 'Something went wrong.');
    });

    test('exception carries the raw error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '1234',
      );
      expect(result.exception, isA<StateError>());
      expect((result.exception as StateError).message, 'submit error');
    });
  });

  group('sendCommand — unexpected failure', () {
    test('returns failure outcome', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );
      expect(result.isSuccess, isFalse);
      expect(result.outcome, CommandOutcome.failure);
    });

    test('message is always generic', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );
      expect(result.message, 'Something went wrong.');
    });

    test('exception carries the raw error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );
      expect(result.exception, isA<StateError>());
      expect((result.exception as StateError).message, 'send error');
    });
  });

  group('sendText — unexpected failure', () {
    test('returns failure outcome', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.isSuccess, isFalse);
      expect(result.outcome, CommandOutcome.failure);
    });

    test('message is always generic', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.message, 'Something went wrong.');
    });

    test('exception carries the raw error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.exception, isA<StateError>());
      expect((result.exception as StateError).message, 'text error');
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _RecordingAdapter implements TvBrandAdapter {
  _RecordingAdapter({
    required this.brand,
    bool supportsTextInput = true,
    Set<RemoteCommand>? supportedCommands,
    Stream<bool>? textInputReadyStream,
  })  : _supportsTextInput = supportsTextInput,
        _supportedCommands = supportedCommands ?? RemoteCommand.values.toSet(),
        _textInputReadyStream = textInputReadyStream ?? const Stream.empty();

  @override
  final TvBrand brand;

  final bool _supportsTextInput;
  final Set<RemoteCommand> _supportedCommands;
  final Stream<bool> _textInputReadyStream;

  int preparePairingCallCount = 0;
  int submitPairingCodeCallCount = 0;
  int sendCommandCallCount = 0;
  int sendTextCallCount = 0;

  @override
  bool get supportsTextInput => _supportsTextInput;

  @override
  Set<RemoteCommand> get supportedCommands => _supportedCommands;

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<void> preparePairing({required TvDevice device}) async {
    preparePairingCallCount++;
  }

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    submitPairingCodeCallCount++;
  }

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    sendCommandCallCount++;
  }

  @override
  Future<void> sendText({required TvDevice device, required String text}) async {
    sendTextCallCount++;
  }

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      _textInputReadyStream;
}

class _ThrowingAdapter implements TvBrandAdapter {
  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => RemoteCommand.values.toSet();

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<void> preparePairing({required TvDevice device}) async {
    throw StateError('pairing error');
  }

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    throw StateError('submit error');
  }

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    throw StateError('send error');
  }

  @override
  Future<void> sendText({required TvDevice device, required String text}) async {
    throw StateError('text error');
  }

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);
}
