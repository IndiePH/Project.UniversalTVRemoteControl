import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_legacy_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_legacy_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class TclLegacyWifiAdapter implements TvBrandAdapter {
  TclLegacyWifiAdapter({required this._transportClient, CommandKeyMap? keyMap})
    : _keyMap = keyMap ?? const TclLegacyKeyMapper();

  final TclLegacyTransportClient _transportClient;
  final CommandKeyMap _keyMap;

  static const Set<RemoteCommand> _supportedCommands = {
    RemoteCommand.power,
    RemoteCommand.playPause,
    RemoteCommand.volumeUp,
    RemoteCommand.volumeDown,
    RemoteCommand.channelUp,
    RemoteCommand.channelDown,
    RemoteCommand.mute,
    RemoteCommand.input,
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
  TvBrand get brand => TvBrand.tcl;

  @override
  String get protocolVariant => TclProtocolVariants.legacyWifi;

  @override
  bool get supportsTextInput => false;

  @override
  Set<RemoteCommand> get supportedCommands => _supportedCommands;

  @override
  Future<void> preparePairing({required TvDevice device}) =>
      _transportClient.connect(deviceId: device.id);

  @override
  Future<void> connect({required TvDevice device}) =>
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
    throw UnsupportedError(
      'Pairing code flow is not supported for TCL legacy Wi-Fi TVs.',
    );
  }

  @override
  Future<void> probeConnection({required TvDevice device}) =>
      _transportClient.connect(deviceId: device.id);

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    await _transportClient.connect(deviceId: device.id);
    final frame = _keyMap.primaryKeyCodeFor(command);
    if (frame == null) {
      throw UnsupportedError('No TCL legacy key mapping for command: $command');
    }
    await _transportClient.sendFrame(deviceId: device.id, frame: frame);
  }

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    throw UnsupportedError('Text input is not supported for TCL legacy Wi-Fi.');
  }

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      _transportClient.watchConnectionState(device.id);
}
