import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_legacy_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_legacy_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/key_hold_phase.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

class TclLegacyWifiAdapter implements TvBrandAdapter {
  TclLegacyWifiAdapter({required this._transportClient, CommandKeyMap? keyMap})
    : _keyMap = keyMap ?? const TclLegacyKeyMapper() {
    _supportedCommands = kCommonSupportedRemoteCommands
        .where((command) => _keyMap.payloadFor(command) != null)
        .toSet();
  }

  final TclLegacyTransportClient _transportClient;
  final CommandKeyMap _keyMap;
  late final Set<RemoteCommand> _supportedCommands;

  @override
  TvBrand get brand => TvBrand.tcl;

  @override
  String get protocolVariant => TclProtocolVariants.legacyWifi;

  @override
  bool get supportsTextInput => false;

  // Every send opens a fresh TCP socket (sendFrame) — structurally the worst
  // fit in this codebase for hold emulation. Out of scope, not deferred; see
  // goal-long-press-key.md verified fact #9.
  @override
  bool get supportsKeyHold => false;

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
    final payload = _keyMap.payloadFor(command);
    if (payload == null) {
      throw UnsupportedError('No TCL legacy key mapping for command: $command');
    }
    switch (payload) {
      case KeySequence(:final codes):
        await _transportClient.sendFrame(
          deviceId: device.id,
          frame: codes.first,
        );
      default:
        throw UnsupportedError(
          'TCL legacy Wi-Fi has no dispatch path for ${payload.runtimeType}.',
        );
    }
  }

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    throw UnsupportedError('Text input is not supported for TCL legacy Wi-Fi.');
  }

  @override
  Future<void> sendKeyHold({
    required TvDevice device,
    required RemoteCommand command,
    required KeyHoldPhase phase,
  }) async => throw UnsupportedError(
    'Key hold is not supported for ${device.brand.name}.',
  );

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      _transportClient.watchConnectionState(device.id);
}
