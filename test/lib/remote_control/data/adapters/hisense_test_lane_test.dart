import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  const hisenseDevice = TvDevice(
    id: 'hisense-test',
    displayName: 'Hisense Test TV',
    brand: TvBrand.hisense,
    capabilities: {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
    },
  );

  // --- preparePairing ---

  test('Hisense adapter: preparePairing calls connect on the transport', () async {
    final transport = _SpyHisenseTransportClient();
    final adapter = HisenseAdapter(transportClient: transport);
    await adapter.preparePairing(device: hisenseDevice);
    expect(transport.connectCalls, 1);
  });

  test('Hisense lane: preparePairing success when transport connects cleanly', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [HisenseAdapter(transportClient: _SpyHisenseTransportClient())],
    );
    final result = await service.preparePairing(device: hisenseDevice);
    expect(result.isSuccess, isTrue);
  });

  // --- sendCommand: key routing ---

  test('Hisense adapter: sendCommand routes key command to transport sendKey', () async {
    final transport = _SpyHisenseTransportClient();
    final adapter = HisenseAdapter(transportClient: transport);
    await adapter.sendCommand(device: hisenseDevice, command: RemoteCommand.volumeUp);
    expect(transport.sentKeys, contains('KEY_VOLUMEUP'));
  });

  test('Hisense lane: sendCommand key route completes successfully', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [HisenseAdapter(transportClient: _SpyHisenseTransportClient())],
    );
    final result = await service.sendCommand(
      device: hisenseDevice,
      command: RemoteCommand.volumeUp,
    );
    expect(result.isSuccess, isTrue);
  });

  // --- sendCommand: app-launch routing ---

  test('Hisense adapter: sendCommand routes netflix to launchVidaaApp', () async {
    final transport = _SpyHisenseTransportClient();
    final adapter = HisenseAdapter(transportClient: transport);
    await adapter.sendCommand(device: hisenseDevice, command: RemoteCommand.netflix);
    expect(transport.launchedApps, contains('Netflix'));
    expect(transport.sentKeys, isEmpty);
  });

  test('Hisense adapter: sendCommand routes primeVideo to launchVidaaApp', () async {
    final transport = _SpyHisenseTransportClient();
    final adapter = HisenseAdapter(transportClient: transport);
    await adapter.sendCommand(device: hisenseDevice, command: RemoteCommand.primeVideo);
    expect(transport.launchedApps, contains('Amazon'));
  });

  test('Hisense adapter: sendCommand routes disneyPlus to launchVidaaApp', () async {
    final transport = _SpyHisenseTransportClient();
    final adapter = HisenseAdapter(transportClient: transport);
    await adapter.sendCommand(device: hisenseDevice, command: RemoteCommand.disneyPlus);
    expect(transport.launchedApps, contains('Disney+'));
  });

  test('Hisense adapter: sendCommand routes web to launchVidaaApp', () async {
    final transport = _SpyHisenseTransportClient();
    final adapter = HisenseAdapter(transportClient: transport);
    await adapter.sendCommand(device: hisenseDevice, command: RemoteCommand.web);
    expect(transport.launchedApps, contains('YouTube'));
  });

  // --- sendText ---

  test('Hisense adapter: sendText throws UnsupportedError', () async {
    final adapter = HisenseAdapter(transportClient: _SpyHisenseTransportClient());
    await expectLater(
      () => adapter.sendText(device: hisenseDevice, text: 'hello'),
      throwsUnsupportedError,
    );
  });

  test('Hisense lane: sendText returns unsupported (supportsTextInput is false)', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [HisenseAdapter(transportClient: _SpyHisenseTransportClient())],
    );
    final result = await service.sendText(device: hisenseDevice, text: 'hello');
    expect(result.isSuccess, isFalse);
    expect(result.outcome, CommandOutcome.unsupported);
    expect(result.message, contains('not supported'));
  });

  // --- submitPairingCode ---

  test('Hisense adapter: submitPairingCode forwards pin to transport', () async {
    final transport = _SpyHisenseTransportClient();
    final adapter = HisenseAdapter(transportClient: transport);
    await adapter.submitPairingCode(device: hisenseDevice, fourDigitPin: '5678');
    expect(transport.submittedPins, contains('5678'));
  });

  test('Hisense lane: submitPairingCode success when transport accepts pin', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [HisenseAdapter(transportClient: _SpyHisenseTransportClient())],
    );
    final result = await service.submitPairingCode(
      device: hisenseDevice,
      fourDigitPin: '5678',
    );
    expect(result.isSuccess, isTrue);
  });

  test('Hisense lane: submitPairingCode error surfaces as failure', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [HisenseAdapter(transportClient: _ErrorOnPinHisenseTransportClient())],
    );
    final result = await service.submitPairingCode(
      device: hisenseDevice,
      fourDigitPin: '0000',
    );
    expect(result.isSuccess, isFalse);
  });

  // --- unpairDevice ---

  test('Hisense adapter: unpairDevice is a no-op and completes without error', () async {
    final adapter = HisenseAdapter(transportClient: _SpyHisenseTransportClient());
    await expectLater(
      adapter.unpairDevice(device: hisenseDevice),
      completes,
    );
  });

  test('Hisense lane: unpairDevice completes without error', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [HisenseAdapter(transportClient: _SpyHisenseTransportClient())],
    );
    await expectLater(
      service.unpairDevice(device: hisenseDevice),
      completes,
    );
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _SpyHisenseTransportClient
    with TransportEventEmitterMixin
    implements HisenseTransportClient {
  int connectCalls = 0;
  final List<String> sentKeys = [];
  final List<String> launchedApps = [];
  final List<String> submittedPins = [];

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
  Future<void> sendKey({required String deviceId, required String keyName}) async {
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
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}
