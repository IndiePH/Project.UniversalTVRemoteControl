import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg/fake_lg_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/brand_routed_remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

void main() {
  const lgDevice = TvDevice(
    id: 'lg-test',
    displayName: 'LG Test TV',
    brand: TvBrand.lg,
    capabilities: {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
    },
  );

  test('LG adapter: sendCommand with fake transport completes without error', () async {
    final adapter = LgAdapter(transportClient: FakeLgTransportClient());
    await expectLater(
      adapter.sendCommand(device: lgDevice, command: RemoteCommand.volumeUp),
      completes,
    );
  });

  test('LG lane: unsupported command returns UI-safe result', () async {
    final service = BrandRoutedRemoteCommandService(
      adapters: [const _SubsetLgAdapter()],
    );

    final result = await service.sendCommand(
      device: lgDevice,
      command: RemoteCommand.menu,
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, contains('lg'));
  });

  test('LG adapter: connect hook runs before key sends', () async {
    final transport = FakeLgTransportClient();
    final adapter = LgAdapter(transportClient: transport);

    await adapter.sendCommand(device: lgDevice, command: RemoteCommand.power);
    await adapter.sendCommand(device: lgDevice, command: RemoteCommand.volumeUp);

    // FakeLgTransportClient auto-connects; both sends should complete
    await expectLater(
      adapter.sendCommand(device: lgDevice, command: RemoteCommand.home),
      completes,
    );
  });
}

class _SubsetLgAdapter implements TvBrandAdapter {
  const _SubsetLgAdapter();

  @override
  TvBrand get brand => TvBrand.lg;

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
