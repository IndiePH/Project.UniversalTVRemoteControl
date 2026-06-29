import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import '../../../../fakes/fake_localized_strings.dart';

void main() {
  const hisenseDevice = TvDevice(
    id: 'hisense-test',
    displayName: 'Hisense Test TV',
    brand: TvBrand.hisense,
    capabilities: {DeviceCapability.keyCommands, DeviceCapability.powerControl},
  );

  // --- preparePairing ---

  test(
    'Hisense adapter: preparePairing calls connect on the transport',
    () async {
      final transport = _SpyHisenseTransportClient();
      final adapter = HisenseAdapter(transportClient: transport);
      await adapter.preparePairing(device: hisenseDevice);
      expect(transport.connectCalls, 1);
    },
  );

  test(
    'Hisense lane: preparePairing returns pinRequired when transport connects',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          HisenseAdapter(transportClient: _SpyHisenseTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.preparePairing(device: hisenseDevice);
      expect(result.isPinRequired, isTrue);
    },
  );

  // --- sendCommand: key routing ---

  test(
    'Hisense adapter: sendCommand routes key command to transport sendKey',
    () async {
      final transport = _SpyHisenseTransportClient();
      final adapter = HisenseAdapter(transportClient: transport);
      await adapter.sendCommand(
        device: hisenseDevice,
        command: RemoteCommand.volumeUp,
      );
      expect(transport.sentKeys, contains('KEY_VOLUMEUP'));
    },
  );

  test('Hisense lane: sendCommand key route completes successfully', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [HisenseAdapter(transportClient: _SpyHisenseTransportClient())],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      localizedStrings: FakeLocalizedStrings(),
    );
    final result = await service.sendCommand(
      device: hisenseDevice,
      command: RemoteCommand.volumeUp,
    );
    expect(result.isSuccess, isTrue);
  });

  // --- sendCommand: app-launch routing ---

  test(
    'Hisense adapter: sendCommand routes netflix to launchVidaaApp',
    () async {
      final transport = _SpyHisenseTransportClient();
      final adapter = HisenseAdapter(transportClient: transport);
      await adapter.sendCommand(
        device: hisenseDevice,
        command: RemoteCommand.netflix,
      );
      expect(transport.launchedApps, contains('Netflix'));
      expect(transport.sentKeys, isEmpty);
    },
  );

  test(
    'Hisense adapter: sendCommand routes primeVideo to launchVidaaApp',
    () async {
      final transport = _SpyHisenseTransportClient();
      final adapter = HisenseAdapter(transportClient: transport);
      await adapter.sendCommand(
        device: hisenseDevice,
        command: RemoteCommand.primeVideo,
      );
      expect(transport.launchedApps, contains('Amazon'));
    },
  );

  test(
    'Hisense adapter: sendCommand routes disneyPlus to launchVidaaApp',
    () async {
      final transport = _SpyHisenseTransportClient();
      final adapter = HisenseAdapter(transportClient: transport);
      await adapter.sendCommand(
        device: hisenseDevice,
        command: RemoteCommand.disneyPlus,
      );
      expect(transport.launchedApps, contains('Disney+'));
    },
  );

  test('Hisense adapter: sendCommand routes web to launchVidaaApp', () async {
    final transport = _SpyHisenseTransportClient();
    final adapter = HisenseAdapter(transportClient: transport);
    await adapter.sendCommand(
      device: hisenseDevice,
      command: RemoteCommand.web,
    );
    expect(transport.launchedApps, contains('YouTube'));
  });

  // --- sendText ---

  test('Hisense adapter: sendText throws UnsupportedError', () async {
    final adapter = HisenseAdapter(
      transportClient: _SpyHisenseTransportClient(),
    );
    await expectLater(
      () => adapter.sendText(device: hisenseDevice, text: 'hello'),
      throwsUnsupportedError,
    );
  });

  test(
    'Hisense lane: sendText returns unsupported (supportsTextInput is false)',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          HisenseAdapter(transportClient: _SpyHisenseTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.sendText(
        device: hisenseDevice,
        text: 'hello',
      );
      expect(result.isSuccess, isFalse);
      expect(result.getOutcome(), CommandOutcome.unsupported);
      expect(result.message, contains('not supported'));
    },
  );

  // --- submitPairingCode ---

  test(
    'Hisense adapter: submitPairingCode forwards pin and reconnects transport',
    () async {
      final transport = _SpyHisenseTransportClient();
      final adapter = HisenseAdapter(transportClient: transport);
      await adapter.submitPairingCode(device: hisenseDevice, pinCode: '5678');
      expect(transport.submittedPins, contains('5678'));
      expect(transport.connectCalls, 1);
    },
  );

  test(
    'Hisense lane: submitPairingCode success when transport accepts pin',
    () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [
          HisenseAdapter(transportClient: _SpyHisenseTransportClient()),
        ],
        variantRegistry: const DefaultVariantResolutionRegistry(),
        localizedStrings: FakeLocalizedStrings(),
      );
      final result = await service.submitPairingCode(
        device: hisenseDevice,
        pinCode: '5678',
      );
      expect(result.isSuccess, isTrue);
    },
  );

  test('Hisense lane: submitPairingCode error surfaces as failure', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [
        HisenseAdapter(transportClient: _ErrorOnPinHisenseTransportClient()),
      ],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      localizedStrings: FakeLocalizedStrings(),
    );
    final result = await service.submitPairingCode(
      device: hisenseDevice,
      pinCode: '0000',
    );
    expect(result.isSuccess, isFalse);
  });

  // --- unpairDevice ---

  test(
    'Hisense adapter: unpairDevice clears transport pairing for the device',
    () async {
      final transport = _SpyHisenseTransportClient();
      final adapter = HisenseAdapter(transportClient: transport);
      await adapter.unpairDevice(device: hisenseDevice);
      expect(transport.clearedPairings, [hisenseDevice.id]);
    },
  );

  test('Hisense lane: unpairDevice completes without error', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [HisenseAdapter(transportClient: _SpyHisenseTransportClient())],
      variantRegistry: const DefaultVariantResolutionRegistry(),
      localizedStrings: FakeLocalizedStrings(),
    );
    await expectLater(service.unpairDevice(device: hisenseDevice), completes);
  });

  // --- sendCommand: key-alternate fan-out ---

  test('Hisense adapter: sendCommand publishes every key alias for a command '
      'with multiple VIDAA aliases (firmware-variant tolerance)', () async {
    final transport = _SpyHisenseTransportClient();
    final adapter = HisenseAdapter(transportClient: transport);
    await adapter.sendCommand(
      device: hisenseDevice,
      command: RemoteCommand.back,
    );
    expect(
      transport.sentKeys,
      containsAllInOrder(['KEY_RETURNS', 'KEY_RETURN', 'KEY_BACK']),
    );
  });

  test(
    'Hisense adapter: menu publishes firmware-variant aliases in order',
    () async {
      final transport = _SpyHisenseTransportClient();
      final adapter = HisenseAdapter(transportClient: transport);
      await adapter.sendCommand(
        device: hisenseDevice,
        command: RemoteCommand.menu,
      );
      expect(
        transport.sentKeys,
        containsAllInOrder([
          'KEY_MENU',
          'KEY_SETTINGS',
          'KEY_SETTING',
          'KEY_OPTION',
        ]),
      );
    },
  );

  test(
    'Hisense adapter: concurrent connect() and watchConnectionState share one transport connect',
    () async {
      final completer = Completer<void>();
      final transport = _SlowHisenseTransportClient(completer.future);
      final adapter = HisenseAdapter(transportClient: transport);

      adapter.watchConnectionState(hisenseDevice).listen((_) {});
      unawaited(adapter.connect(device: hisenseDevice));

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

class _SlowHisenseTransportClient
    with TransportEventEmitterMixin
    implements HisenseTransportClient {
  _SlowHisenseTransportClient(this._connectFuture);

  final Future<void> _connectFuture;
  int connectCalls = 0;

  @override
  Future<void> connect({required String deviceId}) async {
    connectCalls++;
    await _connectFuture;
  }

  @override
  Future<void> submitAuthenticationCode({
    required String deviceId,
    required String fourDigitPin,
  }) async {}

  @override
  Future<void> sendKey({required String deviceId, required String keyName}) async {}

  @override
  Future<void> launchVidaaApp({
    required String deviceId,
    required String displayName,
    required String url,
    int urlType = 37,
    int storeType = 0,
  }) async {}

  @override
  Future<void> sendText({required String deviceId, required String text}) async {}

  @override
  Future<void> probe(String host) async {}

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}

class _SpyHisenseTransportClient
    with TransportEventEmitterMixin
    implements HisenseTransportClient {
  int connectCalls = 0;
  final List<String> sentKeys = [];
  final List<String> launchedApps = [];
  final List<String> submittedPins = [];
  final List<String> clearedPairings = [];

  @override
  Future<void> connect({required String deviceId}) async {
    connectCalls++;
  }

  @override
  Future<void> submitAuthenticationCode({
    required String deviceId,
    required String fourDigitPin,
  }) async {
    submittedPins.add(fourDigitPin);
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyName,
  }) async {
    sentKeys.add(keyName);
  }

  @override
  Future<void> launchVidaaApp({
    required String deviceId,
    required String displayName,
    required String url,
    int urlType = 37,
    int storeType = 0,
  }) async {
    launchedApps.add(displayName);
  }

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Future<void> probe(String host) async {}

  @override
  Future<void> clearPairing({required String deviceId}) async {
    clearedPairings.add(deviceId);
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}

class _ErrorOnPinHisenseTransportClient
    with TransportEventEmitterMixin
    implements HisenseTransportClient {
  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<void> submitAuthenticationCode({
    required String deviceId,
    required String fourDigitPin,
  }) async {
    throw StateError('Incorrect pairing code.');
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyName,
  }) async {}

  @override
  Future<void> launchVidaaApp({
    required String deviceId,
    required String displayName,
    required String url,
    int urlType = 37,
    int storeType = 0,
  }) async {}

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Future<void> probe(String host) async {}

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.error);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}
