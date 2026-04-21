import 'package:one_remote/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg/fake_lg_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg/lg_key_mapper.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg/lg_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

class LgAdapter implements TvBrandAdapter {
  LgAdapter({
    LgTransportClient? transportClient,
    CommandKeyMap? keyMap,
  }) : _transportClient = transportClient ?? FakeLgTransportClient(),
       _keyMap = keyMap ?? const LgKeyMapper();

  @override
  TvBrand get brand => TvBrand.lg;

  @override
  bool get supportsTextInput => false;

  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands;

  final LgTransportClient _transportClient;
  final CommandKeyMap _keyMap;

  @override
  Future<void> preparePairing({required TvDevice device}) async {
    // Register the key completer before connect so it is in place when
    // the TV sends the client-key response after the user approves the prompt.
    final clientKeyFuture = _transportClient.requestClientKey(deviceId: device.id);
    await _transportClient.connect(deviceId: device.id);
    await clientKeyFuture; // key storage wired in T-2.2
  }

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    throw UnsupportedError('LG uses a client-key flow, not a PIN code.');
  }

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final keyCode = _keyMap.primaryKeyCodeFor(command);
    if (keyCode == null) {
      throw UnsupportedError('No LG key mapping for command: $command');
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

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) async* {
    try {
      await _transportClient.connect(deviceId: device.id);
    } catch (_) {
      yield false;
      return;
    }
    yield* _transportClient.watchRemoteTextInputReady(device.id);
  }
}
