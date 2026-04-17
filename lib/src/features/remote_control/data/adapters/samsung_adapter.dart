import 'package:universal_tv_remove_control/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/adapters/samsung/fake_samsung_transport_client.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/adapters/samsung/samsung_key_mapper.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/remote_command.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_device.dart';

class SamsungAdapter implements TvBrandAdapter {
  SamsungAdapter({
    SamsungTransportClient? transportClient,
    SamsungKeyMapper? keyMapper,
  }) : _transportClient = transportClient ?? FakeSamsungTransportClient(),
       _keyMapper = keyMapper ?? const SamsungKeyMapper();

  static const Set<RemoteCommand> _supportedCommands = {
    RemoteCommand.power,
    RemoteCommand.playPause,
    RemoteCommand.volumeUp,
    RemoteCommand.volumeDown,
    RemoteCommand.channelUp,
    RemoteCommand.channelDown,
    RemoteCommand.mute,
    RemoteCommand.input,
    RemoteCommand.web,
    RemoteCommand.netflix,
    RemoteCommand.primeVideo,
    RemoteCommand.disneyPlus,
    RemoteCommand.dpadUp,
    RemoteCommand.dpadDown,
    RemoteCommand.dpadLeft,
    RemoteCommand.dpadRight,
    RemoteCommand.dpadOk,
    RemoteCommand.back,
    RemoteCommand.home,
    RemoteCommand.menu,
  };

  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => _supportedCommands;

  final SamsungTransportClient _transportClient;
  final SamsungKeyMapper _keyMapper;

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final keyCode = _keyMapper.keyCodeFor(command);
    if (keyCode == null) {
      throw UnsupportedError('No Samsung key mapping for command: $command');
    }
    await _transportClient.connect(deviceId: device.id);
    await _transportClient.sendKey(deviceId: device.id, keyCode: keyCode);
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
