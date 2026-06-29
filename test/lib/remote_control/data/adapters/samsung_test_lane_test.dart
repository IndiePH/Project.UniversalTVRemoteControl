import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_authorization.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/text_compatibility_error.dart';
import 'package:one_remote/remote_control/application/text_input_compatibility_exception.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
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
  const samsungDevice = TvDevice(
    id: 'samsung-test',
    displayName: 'Samsung Test TV',
    brand: TvBrand.samsung,
    capabilities: {
      DeviceCapability.keyCommands,
      DeviceCapability.textInput,
      DeviceCapability.powerControl,
    },
  );

  const samsungDeviceNoTextInput = TvDevice(
    id: 'samsung-test',
    displayName: 'Samsung Test TV',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands, DeviceCapability.powerControl},
  );

  // --- Existing tests (preserved from test/samsung_test_lane_test.dart) ---

  test('Samsung lane: unsupported command returns UI-safe result', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [const _SubsetSamsungAdapter()],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      localizedStrings: FakeLocalizedStrings(),
    );

    final result = await service.sendCommand(
      device: samsungDevice,
      command: RemoteCommand.menu,
    );

    expect(result.isSuccess, isFalse);
    expect(
      result.message,
      contains('Command menu is not supported for samsung.'),
    );
  });

  test(
    'Samsung lane: compatibility text exception is surfaced safely',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [const _CompatibilitySamsungAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );

      final result = await service.sendText(
        device: samsungDevice,
        text: 'hello',
      );

      expect(result.isSuccess, isFalse);
      expect(result.getOutcome(), CommandOutcome.compatibility);
      expect(
        result.message,
        FakeLocalizedStrings().remoteTextSamsungCompatibilityError,
      );
    },
  );

  test(
    'Samsung lane: text send returns unsupported when flag is off',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [const _SubsetSamsungAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );

      final result = await service.sendText(
        device: samsungDevice,
        text: 'hello',
      );

      expect(result.isSuccess, isFalse);
      expect(result.getOutcome(), CommandOutcome.unsupported);
      expect(
        result.message,
        contains('Text input is not supported for samsung.'),
      );
    },
  );

  test('Samsung adapter: connect hook runs before key/text sends', () async {
    final transport = _SpySamsungTransportClient();
    final adapter = SamsungAdapter(transportClient: transport);

    await adapter.sendCommand(
      device: samsungDevice,
      command: RemoteCommand.power,
    );
    await adapter.sendText(device: samsungDevice, text: 'hello');

    expect(transport.connectCalls, 2);
    expect(transport.sendKeyCalls, greaterThan(0));
    expect(transport.sendTextCalls, 1);
  });

  test(
    'Samsung adapter: watch readiness does not trigger eager reconnect',
    () async {
      final transport = _SpySamsungTransportClient(throwOnConnect: true);
      final adapter = SamsungAdapter(transportClient: transport);

      final values = await adapter
          .watchRemoteTextInputReady(samsungDevice)
          .toList();

      expect(values, [true]);
      expect(transport.connectCalls, 0);
    },
  );

  // --- T-07 additions ---

  test(
    'Samsung lane: preparePairing success when transport accepts approval',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          SamsungAdapter(transportClient: _SpySamsungTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.preparePairing(device: samsungDevice);
      expect(result.isSuccess, isTrue);
    },
  );

  test(
    'Samsung lane: approval timeout surfaces as CommandDispatchResult.failure',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          SamsungAdapter(transportClient: _TimeoutSamsungTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.preparePairing(device: samsungDevice);
      expect(result.isSuccess, isFalse);
      expect(result.message, 'Pairing failed for Samsung Test TV.');
      expect(result.exception, isA<TimeoutException>());
      expect(
        result.exception.toString(),
        contains('Timed out waiting for Samsung TV approval'),
      );
      expect(
        result.exception.toString(),
        contains('Approve the TV popup and retry pairing'),
      );
    },
  );

  test(
    'Samsung lane: authorization rejection surfaces as CommandDispatchResult.failure',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          SamsungAdapter(transportClient: _RejectingSamsungTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.preparePairing(device: samsungDevice);
      expect(result.isSuccess, isFalse);
      expect(result.message, 'Pairing failed for Samsung Test TV.');
      expect(result.exception, isA<SamsungTransportAuthorizationException>());
      expect(
        result.exception.toString(),
        contains('Samsung TV rejected remote-control authorization'),
      );
    },
  );

  test(
    'Samsung lane: retry after approval failure succeeds when transport accepts',
    () async {
      final transport = _FlakySamsungTransportClient(
        failuresBeforeSuccess: 1,
        failure: () => throw TimeoutException(
          'Timed out waiting for Samsung TV approval. '
          'Approve the TV popup and retry pairing.',
        ),
      );
      final service = BrandRoutedRemoteCommandService(
        adapters: [SamsungAdapter(transportClient: transport)],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );

      final first = await service.preparePairing(device: samsungDevice);
      expect(first.isSuccess, isFalse);
      expect(first.exception, isA<TimeoutException>());

      final second = await service.preparePairing(device: samsungDevice);
      expect(second.isSuccess, isTrue);
      expect(transport.approvalRequestCount, 2);
    },
  );

  test(
    'Samsung adapter: cancelPairing delegates to transport for recovery cleanup',
    () async {
      final transport = _SpySamsungTransportClient();
      final adapter = SamsungAdapter(transportClient: transport);
      await adapter.cancelPairing(device: samsungDevice);
      expect(transport.cancelPairingCalls, 1);
      expect(transport.cancelPairingDeviceIds, [samsungDevice.id]);
    },
  );

  test(
    'Samsung lane: submitPairingCode returns unsupported (Samsung does not require a PIN)',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          SamsungAdapter(transportClient: _SpySamsungTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.submitPairingCode(
        device: samsungDevice,
        pinCode: '1234',
      );
      expect(result.isSuccess, isFalse);
      expect(result.getOutcome(), CommandOutcome.unsupported);
      expect(result.message, contains('not required'));
    },
  );

  test(
    'Samsung adapter: unpairDevice clears transport pairing for the device',
    () async {
      final transport = _SpySamsungTransportClient();
      final adapter = SamsungAdapter(transportClient: transport);
      await adapter.unpairDevice(device: samsungDevice);
      expect(transport.clearPairingCalls, 1);
      expect(transport.clearPairingDeviceIds, [samsungDevice.id]);
    },
  );

  test('Samsung lane: unpairDevice completes without error', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [SamsungAdapter(transportClient: _SpySamsungTransportClient())],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      localizedStrings: FakeLocalizedStrings(),
    );
    await expectLater(service.unpairDevice(device: samsungDevice), completes);
  });

  test('Samsung adapter: back publishes fallback aliases in order', () async {
    final transport = _SpySamsungTransportClient();
    final adapter = SamsungAdapter(transportClient: transport);
    await adapter.sendCommand(
      device: samsungDevice,
      command: RemoteCommand.back,
    );
    expect(transport.sentKeyCodes, ['KEY_RETURN', 'KEY_BACK']);
  });

  test(
    'Samsung lane: watchRemoteTextInputReady returns false when device lacks textInput capability',
    () async {
      // _CompatibilitySamsungAdapter has supportsTextInput=true so the service
      // proceeds past that gate and reaches the capability check.
      final service = BrandRoutedRemoteCommandService(
        adapters: [const _CompatibilitySamsungAdapter()],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final values = await service
          .watchRemoteTextInputReady(device: samsungDeviceNoTextInput)
          .toList();
      expect(values, [false]);
    },
  );

  test(
    'Samsung adapter: app shortcuts route launch keys for web/netflix/prime',
    () async {
      final transport = _SpySamsungTransportClient();
      final adapter = SamsungAdapter(transportClient: transport);

      await adapter.sendCommand(
        device: samsungDevice,
        command: RemoteCommand.web,
      );
      await adapter.sendCommand(
        device: samsungDevice,
        command: RemoteCommand.netflix,
      );
      await adapter.sendCommand(
        device: samsungDevice,
        command: RemoteCommand.primeVideo,
      );

      expect(transport.sentKeyCodes, [
        'LAUNCH:org.tizen.browser',
        'LAUNCH:3201907018807',
        'LAUNCH:3201910019365',
      ]);
    },
  );

  test('Samsung adapter: menu publishes fallback aliases in order', () async {
    final transport = _SpySamsungTransportClient();
    final adapter = SamsungAdapter(transportClient: transport);
    await adapter.sendCommand(
      device: samsungDevice,
      command: RemoteCommand.menu,
    );
    expect(
      transport.sentKeyCodes,
      containsAllInOrder([
        'KEY_MENU',
        'KEY_SETTINGS',
        'KEY_SETTING',
        'KEY_OPTION',
      ]),
    );
  });

  test(
    'Samsung adapter: probeRemoteTextInputReady triggers transport probe command',
    () async {
      final transport = _SpySamsungTransportClient();
      final adapter = SamsungAdapter(transportClient: transport);
      final ready = await adapter.probeRemoteTextInputReady(
        device: samsungDevice,
      );
      expect(ready, isTrue);
      expect(transport.probeRemoteTextInputReadyCalls, 1);
    },
  );

  test(
    'Samsung adapter: concurrent connect() and watchConnectionState share one transport connect',
    () async {
      final completer = Completer<void>();
      final transport = _SlowSamsungTransportClient(completer.future);
      final adapter = SamsungAdapter(transportClient: transport);

      adapter.watchConnectionState(samsungDevice).listen((_) {});
      unawaited(adapter.connect(device: samsungDevice));

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

class _SpySamsungTransportClient implements SamsungTransportClient {
  _SpySamsungTransportClient({this.throwOnConnect = false});

  final bool throwOnConnect;
  int connectCalls = 0;
  int sendKeyCalls = 0;
  int sendTextCalls = 0;
  int probeRemoteTextInputReadyCalls = 0;
  int cancelPairingCalls = 0;
  final List<String> cancelPairingDeviceIds = [];
  int clearPairingCalls = 0;
  final List<String> clearPairingDeviceIds = [];
  final List<String> sentKeyCodes = [];

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();

  @override
  Future<void> connect({required String deviceId}) async {
    connectCalls += 1;
    if (throwOnConnect) {
      throw StateError('connect failed');
    }
  }

  @override
  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    sendKeyCalls += 1;
    sentKeyCodes.add(keyCode);
  }

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {
    sendTextCalls += 1;
  }

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(true);

  @override
  Future<bool> probeRemoteTextInputReady({
    required String deviceId,
    Duration timeout = const Duration(milliseconds: 750),
  }) async {
    probeRemoteTextInputReadyCalls += 1;
    return true;
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Future<void> probe(String host) async {}

  @override
  TvDeviceInfo? getCachedDeviceInfo(String deviceId) => null;

  @override
  void cancelPairing(String deviceId) {
    cancelPairingCalls += 1;
    cancelPairingDeviceIds.add(deviceId);
  }

  @override
  Future<void> clearPairing({required String deviceId}) async {
    clearPairingCalls += 1;
    clearPairingDeviceIds.add(deviceId);
  }
}

class _SlowSamsungTransportClient implements SamsungTransportClient {
  _SlowSamsungTransportClient(this._connectFuture);

  final Future<void> _connectFuture;
  int connectCalls = 0;

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();

  @override
  Future<void> connect({required String deviceId}) async {
    connectCalls++;
    await _connectFuture;
  }

  @override
  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<void> sendKey({required String deviceId, required String keyCode}) async {}

  @override
  Future<void> sendText({required String deviceId, required String text}) async {}

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<bool> probeRemoteTextInputReady({
    required String deviceId,
    Duration timeout = const Duration(milliseconds: 750),
  }) async => false;

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Future<void> probe(String host) async {}

  @override
  TvDeviceInfo? getCachedDeviceInfo(String deviceId) => null;

  @override
  void cancelPairing(String deviceId) {}

  @override
  Future<void> clearPairing({required String deviceId}) async {}
}

class _TimeoutSamsungTransportClient implements SamsungTransportClient {
  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();

  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  }) async {
    throw TimeoutException(
      'Timed out waiting for Samsung TV approval. '
      'Approve the TV popup and retry pairing.',
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
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<bool> probeRemoteTextInputReady({
    required String deviceId,
    Duration timeout = const Duration(milliseconds: 750),
  }) async => false;

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.disconnected);

  @override
  Future<void> probe(String host) async {}

  @override
  @override
  TvDeviceInfo? getCachedDeviceInfo(String deviceId) => null;

  @override
  void cancelPairing(String deviceId) {}

  @override
  Future<void> clearPairing({required String deviceId}) async {}
}

class _RejectingSamsungTransportClient implements SamsungTransportClient {
  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();

  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  }) async {
    throw const SamsungTransportAuthorizationException(
      'Samsung TV rejected remote-control authorization.',
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
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(false);

  @override
  Future<bool> probeRemoteTextInputReady({
    required String deviceId,
    Duration timeout = const Duration(milliseconds: 750),
  }) async => false;

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.disconnected);

  @override
  Future<void> probe(String host) async {}

  @override
  @override
  TvDeviceInfo? getCachedDeviceInfo(String deviceId) => null;

  @override
  void cancelPairing(String deviceId) {}

  @override
  Future<void> clearPairing({required String deviceId}) async {}
}

class _FlakySamsungTransportClient implements SamsungTransportClient {
  _FlakySamsungTransportClient({
    required this.failuresBeforeSuccess,
    required this.failure,
  });

  final int failuresBeforeSuccess;
  final void Function() failure;

  int approvalRequestCount = 0;

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();

  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  }) async {
    approvalRequestCount += 1;
    if (approvalRequestCount <= failuresBeforeSuccess) {
      failure();
    }
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
  Stream<bool> watchRemoteTextInputReady(String deviceId) =>
      Stream<bool>.value(true);

  @override
  Future<bool> probeRemoteTextInputReady({
    required String deviceId,
    Duration timeout = const Duration(milliseconds: 750),
  }) async => true;

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Future<void> probe(String host) async {}

  @override
  @override
  TvDeviceInfo? getCachedDeviceInfo(String deviceId) => null;

  @override
  void cancelPairing(String deviceId) {}

  @override
  Future<void> clearPairing({required String deviceId}) async {}
}

class _SubsetSamsungAdapter implements TvBrandAdapter {
  const _SubsetSamsungAdapter();

  @override
  TvBrand get brand => TvBrand.samsung;

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
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {}

  @override
  Future<void> connect({required TvDevice device}) async {}

  @override
  Future<void> probeConnection({required TvDevice device}) async {}

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      Stream<ConnectionState>.value(ConnectionState.connected);
}

class _CompatibilitySamsungAdapter implements TvBrandAdapter {
  const _CompatibilitySamsungAdapter();

  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  String get protocolVariant => TvDevice.defaultProtocolVariant;

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => RemoteCommand.values.toSet();

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
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    throw TextInputCompatibilityException(
      TextCompatibilityError.samsungScreenNotAcceptingInput,
    );
  }

  @override
  Future<void> connect({required TvDevice device}) async {}

  @override
  Future<void> probeConnection({required TvDevice device}) async {}

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      Stream<ConnectionState>.value(ConnectionState.connected);
}
