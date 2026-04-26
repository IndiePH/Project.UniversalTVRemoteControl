import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/transport_log_provider.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import 'package:one_remote/remote_control/domain/models/tv_model_capability_registry.dart';

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
      final service = BrandRoutedRemoteCommandService(
      adapters: [samsung, lg],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );

      await service.preparePairing(device: device);

      expect(samsung.preparePairingCallCount, 1);
      expect(lg.preparePairingCallCount, 0);
    });

    test('returns unsupported when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(
      adapters: [],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
      final result = await service.preparePairing(device: device);
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('samsung'));
    });

    test('returns success when adapter succeeds', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_RecordingAdapter(brand: TvBrand.samsung)],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.preparePairing(device: device);
      expect(result.isSuccess, isTrue);
    });
  });

  // 5.2 — Enrichment: preparePairing resolves capabilities + variant via registries
  // and carries the enriched device in result.device.

  group('preparePairing enrichment', () {
    test('result.device is non-null on success', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_RecordingAdapter(brand: TvBrand.samsung)],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.preparePairing(device: device);
      expect(result.isSuccess, isTrue);
      expect(result.device, isNotNull);
    });

    test('result.device carries capabilities resolved by capabilityRegistry', () async {
      const resolved = {DeviceCapability.keyCommands};
      final service = BrandRoutedRemoteCommandService(
        adapters: [_InfoReturningAdapter(const TvDeviceInfo(modelIdentifier: 'ModelX'))],
        capabilityRegistry: _StubCapabilityRegistry(resolved),
        variantRegistry: const DefaultVariantResolutionRegistry(),
      );
      final result = await service.preparePairing(device: device);
      expect(result.device!.capabilities, equals(resolved));
    });

    test('result.device carries protocolVariant resolved by variantRegistry', () async {
      const variant = 'webos_v2';
      final service = BrandRoutedRemoteCommandService(
        adapters: [_InfoReturningAdapter(const TvDeviceInfo(modelIdentifier: 'ModelX'))],
        variantRegistry: const _StubVariantRegistry(variant),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.preparePairing(device: device);
      expect(result.device!.protocolVariant, equals(variant));
    });

    test('result.device uses brand defaults when queryDeviceInfo returns null', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_RecordingAdapter(brand: TvBrand.samsung)],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.preparePairing(device: device);
      expect(result.device!.capabilities, equals(TvBrand.samsung.defaultCapabilities));
      expect(result.device!.protocolVariant, equals(TvDevice.defaultProtocolVariant));
    });

    test('result.device carries modelIdentifier from queryDeviceInfo', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_InfoReturningAdapter(const TvDeviceInfo(modelIdentifier: 'OLED65C2PSA'))],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.preparePairing(device: device);
      expect(result.device!.modelIdentifier, equals('OLED65C2PSA'));
    });

    test('result.device modelIdentifier is null when queryDeviceInfo returns no model', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_InfoReturningAdapter(const TvDeviceInfo())],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.preparePairing(device: device);
      expect(result.device!.modelIdentifier, isNull);
    });
  });

  group('brand dispatch — submitPairingCode', () {
    test('routes to the matching brand adapter', () async {
      final samsung = _RecordingAdapter(brand: TvBrand.samsung);
      final lg = _RecordingAdapter(brand: TvBrand.lg);
      final service = BrandRoutedRemoteCommandService(
      adapters: [samsung, lg],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );

      await service.submitPairingCode(device: device, fourDigitPin: '1234');

      expect(samsung.submitPairingCodeCallCount, 1);
      expect(lg.submitPairingCodeCallCount, 0);
    });

    test('returns unsupported when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(
      adapters: [],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '0000',
      );
      expect(result.isSuccess, isFalse);
    });

    test('returns success when adapter succeeds', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_RecordingAdapter(brand: TvBrand.samsung)],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
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
      final service = BrandRoutedRemoteCommandService(
      adapters: [samsung, lg],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );

      await service.sendCommand(device: device, command: RemoteCommand.volumeUp);

      expect(samsung.sendCommandCallCount, 1);
      expect(lg.sendCommandCallCount, 0);
    });

    test('returns unsupported when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(
      adapters: [],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
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
      final service = BrandRoutedRemoteCommandService(
      adapters: [adapter],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );

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
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
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
      final service = BrandRoutedRemoteCommandService(
      adapters: [samsung, lg],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );

      await service.sendText(device: device, text: 'hello');

      expect(samsung.sendTextCallCount, 1);
      expect(lg.sendTextCallCount, 0);
    });

    test('returns unsupported when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(
      adapters: [],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.isSuccess, isFalse);
    });

    test('returns unsupported and skips adapter when text input not supported', () async {
      final adapter = _RecordingAdapter(
        brand: TvBrand.samsung,
        supportsTextInput: false,
      );
      final service = BrandRoutedRemoteCommandService(
      adapters: [adapter],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );

      final result = await service.sendText(device: device, text: 'hello');

      expect(result.isSuccess, isFalse);
      expect(adapter.sendTextCallCount, 0);
    });

    test('returns success when adapter succeeds', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_RecordingAdapter(brand: TvBrand.samsung)],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.isSuccess, isTrue);
    });
  });

  group('brand dispatch — watchRemoteTextInputReady', () {
    test('returns false stream when no adapter configured for brand', () async {
      final service = BrandRoutedRemoteCommandService(
      adapters: [],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
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
      final service = BrandRoutedRemoteCommandService(
      adapters: [adapter],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
      final result = await service
          .watchRemoteTextInputReady(device: device)
          .first;
      expect(result, isFalse);
    });

    test('returns false stream when device lacks textInput capability', () async {
      final adapter = _RecordingAdapter(brand: TvBrand.samsung);
      final service = BrandRoutedRemoteCommandService(
      adapters: [adapter],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
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
      final service = BrandRoutedRemoteCommandService(
      adapters: [adapter],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
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
      final service = BrandRoutedRemoteCommandService(
      adapters: [samsung, lg],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
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
      final service = BrandRoutedRemoteCommandService(
      adapters: [samsung, lg],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );
      final result = await service
          .watchRemoteTextInputReady(device: lgDevice)
          .first;
      expect(result, isTrue);
    });
  });

  // 2.17: catch blocks return an operation-specific message and carry the raw
  // exception so env-aware consumers can surface detail in non-production builds.

  group('preparePairing — unexpected failure', () {
    test('returns failure outcome', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.preparePairing(device: device);
      expect(result.isSuccess, isFalse);
      expect(result.getOutcome(), CommandOutcome.failure);
    });

    test('message identifies the operation and device', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.preparePairing(device: device);
      expect(result.message, 'Pairing failed for ${device.displayName}.');
    });

    test('exception carries the raw error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
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
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '1234',
      );
      expect(result.isSuccess, isFalse);
      expect(result.getOutcome(), CommandOutcome.failure);
    });

    test('message identifies the operation and device', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '1234',
      );
      expect(result.message, 'Failed to submit pairing code for ${device.displayName}.');
    });

    test('exception carries the raw error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
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
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );
      expect(result.isSuccess, isFalse);
      expect(result.getOutcome(), CommandOutcome.failure);
    });

    test('message identifies the operation and device', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );
      expect(result.message, 'Failed to send command to ${device.displayName}.');
    });

    test('exception carries the raw error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
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
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.isSuccess, isFalse);
      expect(result.getOutcome(), CommandOutcome.failure);
    });

    test('message identifies the operation and device', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.message, 'Failed to send text to ${device.displayName}.');
    });

    test('exception carries the raw error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.exception, isA<StateError>());
      expect((result.exception as StateError).message, 'text error');
    });
  });

  // 5.4 — TransportLogReaderProvider: routes to adapter log reader when
  // adapter implements TransportLogProvider; falls back to noop otherwise.

  group('TransportLogReaderProvider — readerForDevice', () {
    test('returns reader from adapter when adapter implements TransportLogProvider', () {
      final adapter = _LogProviderAdapter(brand: TvBrand.samsung);
      final service = BrandRoutedRemoteCommandService(
      adapters: [adapter],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );

      final reader = service.readerForDevice(device);
      expect(reader, same(adapter.transportLogReader));
    });

    test('returns NoopTransportLogReader when adapter does not implement TransportLogProvider', () {
      final lg = _RecordingAdapter(brand: TvBrand.lg);
      final service = BrandRoutedRemoteCommandService(
      adapters: [lg],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );

      final reader = service.readerForDevice(lgDevice);
      expect(reader, isA<NoopTransportLogReader>());
    });

    test('returns NoopTransportLogReader when no adapter configured for brand', () {
      final service = BrandRoutedRemoteCommandService(
      adapters: [],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      capabilityRegistry: const DefaultTvModelCapabilityRegistry(),
    );

      final reader = service.readerForDevice(device);
      expect(reader, isA<NoopTransportLogReader>());
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

  @override
  String get protocolVariant => TvDevice.defaultProtocolVariant;

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
  Future<void> probeConnection({required TvDevice device}) async {}

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      _textInputReadyStream;

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;
}

class _ThrowingAdapter implements TvBrandAdapter {
  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  String get protocolVariant => TvDevice.defaultProtocolVariant;

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
  Future<void> probeConnection({required TvDevice device}) async {}

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;
}

class _LogProviderAdapter extends _RecordingAdapter implements TransportLogProvider {
  _LogProviderAdapter({required super.brand}) : _logReader = _StubTransportLogReader();

  final _StubTransportLogReader _logReader;

  @override
  TransportLogReader get transportLogReader => _logReader;
}

class _StubTransportLogReader implements TransportLogReader {
  @override
  Future<String?> readLatestLogForSharing() async => 'stub log';
}

class _InfoReturningAdapter extends _RecordingAdapter {
  _InfoReturningAdapter(this._info) : super(brand: TvBrand.samsung);

  final TvDeviceInfo _info;

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async => _info;
}

class _StubCapabilityRegistry implements TvModelCapabilityRegistry {
  const _StubCapabilityRegistry(this._capabilities);

  final Set<DeviceCapability> _capabilities;

  @override
  Set<DeviceCapability> resolve({
    required TvBrand brand,
    required TvDeviceInfo? info,
  }) => _capabilities;
}

class _StubVariantRegistry implements VariantResolutionRegistry {
  const _StubVariantRegistry(this._variant);

  final String _variant;

  @override
  String resolve({required TvBrand brand, required TvDeviceInfo? info}) => _variant;
}
