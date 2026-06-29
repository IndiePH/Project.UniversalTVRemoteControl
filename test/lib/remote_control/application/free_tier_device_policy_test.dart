import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/free_tier_device_policy.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/data/in_memory_device_repository.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart'
    as remote_connection;
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

void main() {
  const deviceA = TvDevice(
    id: 'a',
    displayName: 'TV A',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands},
  );
  const deviceB = TvDevice(
    id: 'b',
    displayName: 'TV B',
    brand: TvBrand.lg,
    capabilities: {DeviceCapability.keyCommands},
  );

  group('FreeTierDevicePolicy.isFreeTier', () {
    test('is true only for notEntitled', () {
      expect(
        FreeTierDevicePolicy.isFreeTier(ProEntitlementStatus.notEntitled),
        isTrue,
      );
      expect(
        FreeTierDevicePolicy.isFreeTier(ProEntitlementStatus.entitled),
        isFalse,
      );
      expect(
        FreeTierDevicePolicy.isFreeTier(ProEntitlementStatus.unknown),
        isFalse,
      );
    });
  });

  group('FreeTierDevicePolicy.cleanupExtraSavedDevices', () {
    test('reloads saved devices when cleanup removes extras', () async {
      final repository = InMemoryDeviceRepository();
      await repository.saveDevice(deviceA);
      await repository.saveDevice(deviceB);
      final commandService = _RecordingCommandService();

      final outcome = await FreeTierDevicePolicy.cleanupExtraSavedDevices(
        isFreeTier: true,
        activeDeviceId: 'a',
        savedDevices: [deviceA, deviceB],
        commandService: commandService,
        deviceRepository: repository,
      );

      expect(outcome.removed, isTrue);
      expect(outcome.savedDevices.map((d) => d.id), ['a']);
      expect(commandService.unpairedIds, ['b']);
    });

    test('returns original list when not free tier', () async {
      final repository = InMemoryDeviceRepository();
      final commandService = _RecordingCommandService();

      final outcome = await FreeTierDevicePolicy.cleanupExtraSavedDevices(
        isFreeTier: false,
        activeDeviceId: 'a',
        savedDevices: [deviceA, deviceB],
        commandService: commandService,
        deviceRepository: repository,
      );

      expect(outcome.removed, isFalse);
      expect(outcome.savedDevices, [deviceA, deviceB]);
      expect(commandService.unpairedIds, isEmpty);
    });
  });

  group('FreeTierDevicePolicy.replaceActiveDeviceBeforePairingWhenNotPro', () {
    test('replaces active device before pairing on free tier', () async {
      final repository = InMemoryDeviceRepository();
      await repository.saveDevice(deviceA);
      await repository.saveDevice(deviceB);
      final commandService = _RecordingCommandService();

      final replaced =
          await FreeTierDevicePolicy.replaceActiveDeviceBeforePairingWhenNotPro(
            isPro: false,
            activeDeviceId: 'a',
            newDevice: deviceB,
            savedDevices: [deviceA, deviceB],
            commandService: commandService,
            deviceRepository: repository,
          );

      expect(replaced, isTrue);
      expect(commandService.unpairedIds, ['a']);
      expect(await repository.getSavedDevices(), [deviceB]);
    });

    test('does nothing when Pro', () async {
      final repository = InMemoryDeviceRepository();
      await repository.saveDevice(deviceA);
      final commandService = _RecordingCommandService();

      final replaced =
          await FreeTierDevicePolicy.replaceActiveDeviceBeforePairingWhenNotPro(
            isPro: true,
            activeDeviceId: 'a',
            newDevice: deviceB,
            savedDevices: [deviceA],
            commandService: commandService,
            deviceRepository: repository,
          );

      expect(replaced, isFalse);
      expect(commandService.unpairedIds, isEmpty);
    });
  });
}

class _RecordingCommandService implements RemoteCommandService {
  final List<String> unpairedIds = [];

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async =>
      CommandDispatchResult.success('ok');

  @override
  Future<void> cancelPairing({required TvDevice device}) async {}

  @override
  Future<void> connect({required TvDevice device}) async {}

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async =>
      CommandDispatchResult.success('ok');

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async =>
      CommandDispatchResult.success('ok');

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async =>
      CommandDispatchResult.success('ok');

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      RemoteCommand.values.toSet();

  @override
  Stream<remote_connection.ConnectionState> watchConnectionState({
    required TvDevice device,
  }) =>
      const Stream.empty();

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      const Stream.empty();

  @override
  Future<bool> checkRemoteTextInputReady({required TvDevice device}) async =>
      false;

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    unpairedIds.add(device.id);
  }
}
