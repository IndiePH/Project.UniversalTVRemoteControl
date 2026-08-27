import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/roku_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_roku_key_mapper.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class TclRokuAdapter implements TvBrandAdapter {
  TclRokuAdapter({required this._transportClient, CommandKeyMap? keyMap})
    : _keyMap = keyMap ?? const TclRokuKeyMapper() {
    _supportedCommands = kCommonSupportedRemoteCommands
        .where((command) => _keyMap.payloadFor(command) != null)
        .toSet();
  }

  final RokuTransportClient _transportClient;
  final CommandKeyMap _keyMap;
  late final Set<RemoteCommand> _supportedCommands;

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
    final payload = _keyMap.payloadFor(command);
    if (payload == null) {
      throw UnsupportedError('No Roku key mapping for command: $command');
    }
    switch (payload) {
      case KeySequence(:final codes):
        await _transportClient.sendKey(
          deviceId: device.id,
          keyCode: codes.first,
        );
      case AppLink(:final uri):
        await _transportClient.launchApp(deviceId: device.id, appId: uri);
      default:
        throw UnsupportedError(
          'Roku has no dispatch path for ${payload.runtimeType}.',
        );
    }
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
