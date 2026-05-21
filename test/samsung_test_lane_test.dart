import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/src/features/remote_control/application/text_input_compatibility_exception.dart';
import 'package:one_remote/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/transport_event.dart';

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

  test('Samsung lane: unsupported command returns UI-safe result', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [const _SubsetSamsungAdapter()],
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

  test('Samsung lane: compatibility text exception is surfaced safely', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [const _CompatibilitySamsungAdapter()],
    );

    final result = await service.sendText(device: samsungDevice, text: 'hello');

    expect(result.isSuccess, isFalse);
    expect(result.isCompatibilityIssue, isTrue);
    expect(result.message, 'Samsung IME unavailable on this screen.');
  });

  test('Samsung lane: text send returns unsupported when flag is off', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [SamsungAdapter(transportClient: _SpySamsungTransportClient())],
    );

    final result = await service.sendText(device: samsungDevice, text: 'hello');

    expect(result.isSuccess, isFalse);
    expect(result.isCompatibilityIssue, isFalse);
    expect(result.message, contains('Text input is not supported for samsung.'));
  });

  test('Samsung adapter: connect hook runs before key/text sends', () async {
    final transport = _SpySamsungTransportClient();
    final adapter = SamsungAdapter(transportClient: transport);

    await adapter.sendCommand(device: samsungDevice, command: RemoteCommand.power);
    await adapter.sendText(device: samsungDevice, text: 'hello');

    expect(transport.connectCalls, 2);
    expect(transport.sendKeyCalls, greaterThan(0));
    expect(transport.sendTextCalls, 1);
  });

  test('Samsung adapter: watch readiness returns false on connect failure', () async {
    final transport = _SpySamsungTransportClient(throwOnConnect: true);
    final adapter = SamsungAdapter(transportClient: transport);

    final values = await adapter.watchRemoteTextInputReady(samsungDevice).toList();

    expect(values, [false]);
  });
}

class _SpySamsungTransportClient implements SamsungTransportClient {
  _SpySamsungTransportClient({this.throwOnConnect = false});

  final bool throwOnConnect;
  int connectCalls = 0;
  int sendKeyCalls = 0;
  int sendTextCalls = 0;

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
  Future<void> sendKey({required String deviceId, required String keyCode}) async {
    sendKeyCalls += 1;
  }

  @override
  Future<void> sendText({required String deviceId, required String text}) async {
    sendTextCalls += 1;
  }

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) => Stream<bool>.value(true);
}

class _SubsetSamsungAdapter implements TvBrandAdapter {
  const _SubsetSamsungAdapter();

  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  bool get supportsTextInput => false;

  @override
  Set<RemoteCommand> get supportedCommands => const {RemoteCommand.power};

  @override
  Future<void> preparePairing({required TvDevice device}) async {}

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {}

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {}

  @override
  Future<void> sendText({required TvDevice device, required String text}) async {}

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);
}

class _CompatibilitySamsungAdapter implements TvBrandAdapter {
  const _CompatibilitySamsungAdapter();

  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => RemoteCommand.values.toSet();

  @override
  Future<void> preparePairing({required TvDevice device}) async {}

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {}

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {}

  @override
  Future<void> sendText({required TvDevice device, required String text}) async {
    throw TextInputCompatibilityException('Samsung IME unavailable on this screen.');
  }

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);
}
