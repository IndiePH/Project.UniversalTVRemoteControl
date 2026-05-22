import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/roku_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_roku_key_mapper.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class TclRokuAdapter implements TvBrandAdapter {
  TclRokuAdapter({
    required RokuTransportClient transportClient,
    CommandKeyMap? keyMap,
  }) : _transportClient = transportClient,
       _keyMap = keyMap ?? const TclRokuKeyMapper();

  final RokuTransportClient _transportClient;
  final CommandKeyMap _keyMap;

  static const Map<RemoteCommand, String> _appIds = {
    RemoteCommand.netflix: '12',
    RemoteCommand.primeVideo: '13',
    RemoteCommand.youtube: '837',
    RemoteCommand.disneyPlus: '291097',
  };

  static const Set<RemoteCommand> _supportedCommands = {
    RemoteCommand.power,
    RemoteCommand.playPause,
    RemoteCommand.volumeUp,
    RemoteCommand.volumeDown,
    RemoteCommand.channelUp,
    RemoteCommand.channelDown,
    RemoteCommand.mute,
    RemoteCommand.input,
    RemoteCommand.netflix,
    RemoteCommand.primeVideo,
    RemoteCommand.disneyPlus,
    RemoteCommand.youtube,
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
  TvBrand get brand => TvBrand.roku;

  @override
  String get protocolVariant => TvDevice.defaultProtocolVariant;

  @override
  bool get supportsTextInput => false;

  @override
  Set<RemoteCommand> get supportedCommands => _supportedCommands;

  @override
  Future<void> preparePairing({required TvDevice device}) =>
      _transportClient.connect(deviceId: device.id);

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) =>
      _transportClient.queryDeviceInfo(deviceId: device.id);

  @override
  Future<void> unpairDevice({required TvDevice device}) =>
      _transportClient.clearPairing(deviceId: device.id);

  @override
  Future<void> cancelPairing({required TvDevice device}) async {}

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async {
    throw UnsupportedError('Pairing code flow is not supported for Roku TVs.');
  }

  @override
  Future<void> probeConnection({required TvDevice device}) async {
    await _transportClient.connect(deviceId: device.id);
  }

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    await _transportClient.connect(deviceId: device.id);
    final appId = _appIds[command];
    if (appId != null) {
      await _transportClient.launchApp(deviceId: device.id, appId: appId);
      return;
    }
    final key = _keyMap.primaryKeyCodeFor(command);
    if (key == null) {
      throw UnsupportedError('No Roku key mapping for command: $command');
    }
    await _transportClient.sendKey(deviceId: device.id, keyCode: key);
  }

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    throw UnsupportedError('Text input is not supported for Roku TVs.');
  }

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      _transportClient.watchConnectionState(device.id);
}
