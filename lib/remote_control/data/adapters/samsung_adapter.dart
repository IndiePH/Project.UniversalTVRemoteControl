import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_client.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

class SamsungAdapter implements TvBrandAdapter {
  static const bool _samsungTextInputEnabled = bool.fromEnvironment(
    'SAMSUNG_ENABLE_TEXT_INPUT',
    defaultValue: false,
  );

  SamsungAdapter({
    required SamsungTransportClient transportClient,
    CommandKeyMap? keyMapper,
  }) : _transportClient = transportClient,
       _keyMapper = keyMapper ?? const SamsungKeyMapper();

  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  bool get supportsTextInput => _samsungTextInputEnabled;

  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands;

  final SamsungTransportClient _transportClient;
  final CommandKeyMap _keyMapper;

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<void> preparePairing({required TvDevice device}) async {
    final keyCodes = _keyMapper.keyCodesFor(RemoteCommand.back);
    final triggerKeyCode = keyCodes.isNotEmpty ? keyCodes.first : 'KEY_RETURN';
    await _transportClient.requestPairingApproval(
      deviceId: device.id,
      triggerKeyCode: triggerKeyCode,
    );
  }

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    throw UnsupportedError(
      'Samsung pairing code submission is not required in this flow.',
    );
  }

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
