import 'package:flutter_test/flutter_test.dart';
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

  // N-05: kDebugMode guard — all 4 catch blocks return failure and surface
  // error detail in debug builds (tests always run with kDebugMode=true).

  group('preparePairing', () {
    test('returns failure when adapter throws', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.preparePairing(device: device);
      expect(result.isSuccess, isFalse);
      expect(result.isCompatibilityIssue, isFalse);
    });

    test('failure message contains error detail in debug mode', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.preparePairing(device: device);
      expect(result.message, contains('pairing error'));
    });
  });

  group('submitPairingCode', () {
    test('returns failure when adapter throws unexpected error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '1234',
      );
      expect(result.isSuccess, isFalse);
      expect(result.isCompatibilityIssue, isFalse);
    });

    test('failure message contains error detail in debug mode', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.submitPairingCode(
        device: device,
        fourDigitPin: '1234',
      );
      expect(result.message, contains('submit error'));
    });
  });

  group('sendCommand', () {
    test('returns failure when adapter throws', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );
      expect(result.isSuccess, isFalse);
      expect(result.isCompatibilityIssue, isFalse);
    });

    test('failure message contains error detail in debug mode', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendCommand(
        device: device,
        command: RemoteCommand.volumeUp,
      );
      expect(result.message, contains('send error'));
    });
  });

  group('sendText', () {
    test('returns failure when adapter throws unexpected error', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.isSuccess, isFalse);
      expect(result.isCompatibilityIssue, isFalse);
    });

    test('failure message contains error detail in debug mode', () async {
      final service = BrandRoutedRemoteCommandService(
        adapters: [_ThrowingAdapter()],
      );
      final result = await service.sendText(device: device, text: 'hello');
      expect(result.message, contains('text error'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

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
