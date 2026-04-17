import 'package:one_remote/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/fake_samsung_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/samsung_key_mapper.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

class SamsungAdapter implements TvBrandAdapter {
  SamsungAdapter({
    SamsungTransportClient? transportClient,
    CommandKeyMap? keyMapper,
  }) : _transportClient = transportClient ?? FakeSamsungTransportClient(),
       _keyMapper = keyMapper ?? const SamsungKeyMapper();

  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands;

  final SamsungTransportClient _transportClient;
  final CommandKeyMap _keyMapper;

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final keyCodes = _keyMapper.keyCodesFor(command);
    if (keyCodes.isEmpty) {
      throw UnsupportedError('No Samsung key mapping for command: $command');
    }
    await _transportClient.connect(deviceId: device.id);
    for (final keyCode in keyCodes) {
      await _transportClient.sendKey(deviceId: device.id, keyCode: keyCode);
    }
  }

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    await _transportClient.connect(deviceId: device.id);
    await _transportClient.sendText(deviceId: device.id, text: text);
  }
}
