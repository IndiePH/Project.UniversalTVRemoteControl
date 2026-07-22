import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/text_compatibility_error.dart';
import 'package:one_remote/remote_control/application/text_input_compatibility_exception.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/debug/fake_lg_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_exceptions.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import '../../../../fakes/fake_localized_strings.dart';

void main() {
  const lgDevice = TvDevice(
    id: 'lg-test',
    displayName: 'LG Test TV',
    brand: TvBrand.lg,
    capabilities: {DeviceCapability.keyCommands, DeviceCapability.powerControl},
  );

  const lgDeviceWithTextInput = TvDevice(
    id: 'lg-test',
    displayName: 'LG Test TV',
    brand: TvBrand.lg,
    capabilities: {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
      DeviceCapability.textInput,
    },
  );

  // --- T-1.5: Adapter wiring ---

  test(
    'LG adapter: sendCommand with fake transport completes without error',
    () async {
      final adapter = LgAdapter(transportClient: FakeLgTransportClient());
      await expectLater(
        adapter.sendCommand(device: lgDevice, command: RemoteCommand.volumeUp),
        completes,
      );
    },
  );

  test('LG lane: unsupported command returns UI-safe result', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [const _SubsetLgAdapter()],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      localizedStrings: FakeLocalizedStrings(),
    );
    final result = await service.sendCommand(
      device: lgDevice,
      command: RemoteCommand.menu,
    );
    expect(result.isSuccess, isFalse);
    expect(result.message, contains('lg'));
  });

  test('LG adapter: connect hook runs before key sends', () async {
    final adapter = LgAdapter(transportClient: FakeLgTransportClient());
    await adapter.sendCommand(device: lgDevice, command: RemoteCommand.power);
    await adapter.sendCommand(
      device: lgDevice,
      command: RemoteCommand.volumeUp,
    );
    await expectLater(
      adapter.sendCommand(device: lgDevice, command: RemoteCommand.home),
      completes,
    );
  });

  // --- T-4.2: Pairing and reconnection ---

  test(
    'LG lane: preparePairing completes when fake transport issues a key',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [LgAdapter(transportClient: FakeLgTransportClient())],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.preparePairing(device: lgDevice);
      expect(result.isSuccess, isTrue);
    },
  );

  test(
    'LG lane: pairing timeout surfaces as CommandDispatchResult.failure',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [LgAdapter(transportClient: _TimeoutLgTransportClient())],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.preparePairing(device: lgDevice);
      expect(result.isSuccess, isFalse);
      expect(result.message, 'Pairing failed for LG Test TV.');
      expect(result.exception, isA<LgPairingTimeoutException>());
      expect(result.exception.toString(), contains('Timed out'));
    },
  );

  test(
    'LG lane: stale key rejection surfaces as CommandDispatchResult.failure',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [LgAdapter(transportClient: _StaleKeyLgTransportClient())],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.preparePairing(device: lgDevice);
      expect(result.isSuccess, isFalse);
      expect(result.message, 'Pairing failed for LG Test TV.');
      expect(result.exception, isA<LgPairingSessionExpiredException>());
      expect(result.exception.toString(), contains('Re-pairing'));
    },
  );

  // --- T-4.3: Text-input and compatibility ---

  test('LG lane: sendText succeeds', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [LgAdapter(transportClient: FakeLgTransportClient())],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      localizedStrings: FakeLocalizedStrings(),
    );
    final result = await service.sendText(device: lgDevice, text: 'hello');
    expect(result.isSuccess, isTrue);
  });

  test(
    'LG lane: IME rejection surfaces as CommandDispatchResult.compatibility',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          LgAdapter(transportClient: _ImeRejectingLgTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.sendText(device: lgDevice, text: 'hello');
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('focused'));
    },
  );

  // --- T-4.4: Error and reconnect hook tests ---

  test(
    'LG lane: transport throw on sendCommand surfaces as CommandDispatchResult.failure',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [LgAdapter(transportClient: _ErrorOnSendLgTransportClient())],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.sendCommand(
        device: lgDevice,
        command: RemoteCommand.volumeUp,
      );
      expect(result.isSuccess, isFalse);
      expect(result.message, 'Failed to send command to LG Test TV.');
      expect(result.exception, isA<StateError>());
      expect((result.exception as StateError).message, contains('send error'));
    },
  );

  test(
    'LG adapter: reconnects automatically when socket is not open',
    () async {
      final transport = _ReconnectTrackingLgTransportClient();
      final adapter = LgAdapter(transportClient: transport);
      await adapter.sendCommand(
        device: lgDevice,
        command: RemoteCommand.volumeUp,
      );
      await adapter.sendCommand(
        device: lgDevice,
        command: RemoteCommand.volumeDown,
      );
      expect(transport.connectCallCount, greaterThanOrEqualTo(1));
    },
  );

  test('LG adapter: menu publishes fallback aliases in order', () async {
    final transport = _ReconnectTrackingLgTransportClient();
    final adapter = LgAdapter(transportClient: transport);
    await adapter.sendCommand(device: lgDevice, command: RemoteCommand.menu);
    expect(
      transport.sentKeyCodes,
      containsAllInOrder([
        'ssap://com.webos.service.settings/launchSettings',
        'LAUNCH:com.webos.app.settings',
      ]),
    );
  });

  // --- T-06: submitPairingCode ---

  test(
    'LG lane: submitPairingCode returns unsupported (LG uses client-key flow, not PIN)',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [LgAdapter(transportClient: FakeLgTransportClient())],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.submitPairingCode(
        device: lgDevice,
        pinCode: '1234',
      );
      expect(result.isSuccess, isFalse);
      expect(result.getOutcome(), CommandOutcome.unsupported);
      expect(result.message, contains('client-key'));
    },
  );

  // --- T-06: unpairDevice ---

  test('LG adapter: unpairDevice calls clearPairing on transport', () async {
    final transport = _ClearPairingTrackingLgTransportClient();
    final adapter = LgAdapter(transportClient: transport);
    await adapter.unpairDevice(device: lgDevice);
    expect(transport.clearPairingCalls, 1);
  });

  test('LG lane: unpairDevice completes without error', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [LgAdapter(transportClient: FakeLgTransportClient())],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      localizedStrings: FakeLocalizedStrings(),
    );
    await expectLater(service.unpairDevice(device: lgDevice), completes);
  });

  // --- T-06: watchRemoteTextInputReady ---

  test(
    'LG lane: watchRemoteTextInputReady returns adapter stream when device has textInput capability',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          LgAdapter(transportClient: _TextInputReadyLgTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final values = await service
          .watchRemoteTextInputReady(device: lgDeviceWithTextInput)
          .toList();
      expect(values, contains(true));
    },
  );

  test(
    'LG adapter: watch readiness does not trigger eager reconnect',
    () async {
      final transport = _ReconnectTrackingLgTransportClient();
      final adapter = LgAdapter(transportClient: transport);

      final values = await adapter
          .watchRemoteTextInputReady(lgDeviceWithTextInput)
          .toList();

      expect(values, [false]);
      expect(transport.connectCallCount, 0);
    },
  );

  test(
    'LG lane: watchRemoteTextInputReady returns false when no adapter registered',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final values = await service
          .watchRemoteTextInputReady(device: lgDeviceWithTextInput)
          .toList();
      expect(values, [false]);
    },
  );

  test(
    'LG lane: watchRemoteTextInputReady returns false when device lacks textInput capability',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          LgAdapter(transportClient: _TextInputReadyLgTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      // lgDevice has no DeviceCapability.textInput
      final values = await service
          .watchRemoteTextInputReady(device: lgDevice)
          .toList();
      expect(values, [false]);
    },
  );

  test(
    'LG adapter: concurrent connect() and watchConnectionState share one transport connect',
    () async {
      final completer = Completer<void>();
      final transport = _SlowLgTransportClient(completer.future);
      final adapter = LgAdapter(transportClient: transport);

      adapter.watchConnectionState(lgDevice).listen((_) {});
      unawaited(adapter.connect(device: lgDevice));

      await Future<void>.microtask(() {});
      expect(transport.connectCalls, 1);

      completer.complete();
      await Future<void>.microtask(() {});
      expect(transport.connectCalls, 1);
    },
  );
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _SlowLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  _SlowLgTransportClient(this._connectFuture);

  final Future<void> _connectFuture;
  int connectCalls = 0;

  @override
  Future<void> connect({required String deviceId}) async {
    connectCalls++;
    await _connectFuture;
  }

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async => 'key';

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {}

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      Stream<LgRegistrationState>.value(LgRegistrationState.registered);

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<Map<String, dynamic>?> querySystemInfo({
    required String deviceId,
  }) async => null;

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Future<void> disconnect({required String deviceId}) async {}

  @override
  void cancelPairing(String deviceId) {}

  @override
  Future<void> probe(String host) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);
}

class _SubsetLgAdapter implements TvBrandAdapter {
  const _SubsetLgAdapter();

  @override
  TvBrand get brand => TvBrand.lg;

  @override
  String get protocolVariant => TvDevice.defaultProtocolVariant;

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;

  @override
  bool get supportsTextInput => false;

  @override
  Set<RemoteCommand> get supportedCommands => const {RemoteCommand.power};

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<void> cancelPairing({required TvDevice device}) async {}

  @override
  Future<void> preparePairing({required TvDevice device}) async {}

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async {}

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {}

  @override
  Future<void> connect({required TvDevice device}) async {}

  @override
  Future<void> probeConnection({required TvDevice device}) async {}

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {}

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      Stream<ConnectionState>.value(ConnectionState.connected);
}

class _TimeoutLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    throw LgPairingTimeoutException(
      'Timed out waiting for LG TV pairing approval.',
    );
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {}

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      Stream<LgRegistrationState>.value(LgRegistrationState.connecting);

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<Map<String, dynamic>?> querySystemInfo({
    required String deviceId,
  }) async => null;

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Future<void> disconnect({required String deviceId}) async {}

  @override
  void cancelPairing(String deviceId) {}
  @override
  Future<void> probe(String host) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.disconnected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}

class _ErrorOnSendLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async => 'key';

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    throw StateError('send error');
  }

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      Stream<LgRegistrationState>.value(LgRegistrationState.registered);

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<Map<String, dynamic>?> querySystemInfo({
    required String deviceId,
  }) async => null;

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Future<void> disconnect({required String deviceId}) async {}

  @override
  void cancelPairing(String deviceId) {}
  @override
  Future<void> probe(String host) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}

class _ReconnectTrackingLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  int connectCallCount = 0;
  final List<String> sentKeyCodes = [];

  @override
  Future<void> connect({required String deviceId}) async {
    connectCallCount++;
  }

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async => 'key';

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    sentKeyCodes.add(keyCode);
  }

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      Stream<LgRegistrationState>.value(LgRegistrationState.registered);

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<Map<String, dynamic>?> querySystemInfo({
    required String deviceId,
  }) async => null;

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Future<void> disconnect({required String deviceId}) async {}

  @override
  void cancelPairing(String deviceId) {}
  @override
  Future<void> probe(String host) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}

class _ImeRejectingLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async => 'key';

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {}

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {
    throw TextInputCompatibilityException(
      TextCompatibilityError.lgImeFocusRequired,
    );
  }

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      Stream<LgRegistrationState>.value(LgRegistrationState.registered);

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<Map<String, dynamic>?> querySystemInfo({
    required String deviceId,
  }) async => null;

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Future<void> disconnect({required String deviceId}) async {}

  @override
  void cancelPairing(String deviceId) {}
  @override
  Future<void> probe(String host) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}

class _ClearPairingTrackingLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  int clearPairingCalls = 0;

  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async => 'key';

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {}

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      Stream<LgRegistrationState>.value(LgRegistrationState.registered);

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<Map<String, dynamic>?> querySystemInfo({
    required String deviceId,
  }) async => null;

  @override
  Future<void> clearPairing({required String deviceId}) async {
    clearPairingCalls++;
  }

  @override
  Future<void> disconnect({required String deviceId}) async {}

  @override
  void cancelPairing(String deviceId) {}
  @override
  Future<void> probe(String host) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}

class _TextInputReadyLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async => 'key';

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {}

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      Stream<LgRegistrationState>.value(LgRegistrationState.registered);

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(true);

  @override
  Future<Map<String, dynamic>?> querySystemInfo({
    required String deviceId,
  }) async => null;

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Future<void> disconnect({required String deviceId}) async {}

  @override
  void cancelPairing(String deviceId) {}
  @override
  Future<void> probe(String host) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}

class _StaleKeyLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    throw LgPairingSessionExpiredException(
      'LG TV rejected the stored client-key. Re-pairing required.',
    );
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {}

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      Stream<LgRegistrationState>.value(LgRegistrationState.failed);

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<Map<String, dynamic>?> querySystemInfo({
    required String deviceId,
  }) async => null;

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Future<void> disconnect({required String deviceId}) async {}

  @override
  void cancelPairing(String deviceId) {}
  @override
  Future<void> probe(String host) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}
