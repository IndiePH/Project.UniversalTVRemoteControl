import 'package:one_remote/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/hisense/fake_hisense_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/hisense/hisense_key_mapper.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

class HisenseAdapter implements TvBrandAdapter {
  HisenseAdapter({
    HisenseTransportClient? transportClient,
    CommandKeyMap? keyMap,
  }) : _transportClient = transportClient ?? FakeHisenseTransportClient(),
       _keyMap = keyMap ?? const HisenseKeyMapper();

  @override
  TvBrand get brand => TvBrand.hisense;

  @override
  bool get supportsTextInput => false;

  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands;

  final HisenseTransportClient _transportClient;
  final CommandKeyMap _keyMap;

  @override
  Future<void> preparePairing({required TvDevice device}) async {
    await _transportClient.connect(deviceId: device.id);
  }

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    await _transportClient.submitAuthenticationCode(
      deviceId: device.id,
      fourDigitPin: fourDigitPin,
    );
  }

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final launch = _vidaaLaunchSpec(command);
    if (launch != null) {
      await _transportClient.connect(deviceId: device.id);
      await _transportClient.launchVidaaApp(
        deviceId: device.id,
        displayName: launch.$1,
        url: launch.$2,
      );
      return;
    }

    final keyCodes = _keyMap.keyCodesFor(command);
    if (keyCodes.isEmpty) {
      throw UnsupportedError('No Hisense mapping for command: $command');
    }

    await _transportClient.connect(deviceId: device.id);
    await _transportClient.sendKey(
      deviceId: device.id,
      keyName: keyCodes.first,
    );
  }

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  /// Hisense uses VIDAA/MQTT keying and app launch; a separate “type text from phone”
  /// path may land later and will not mirror LG’s webOS approach. Until then,
  /// [supportsTextInput] stays false and we throw so callers never treat sends as no-ops.
  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    throw UnsupportedError(
      'Hisense VIDAA text input from the phone is not implemented yet.',
    );
  }

  /// Returns `(displayName, url)` for MQTT `launchapp` when [command] is an
  /// app shortcut; otherwise `null` (handled via `sendkey`).
  (String, String)? _vidaaLaunchSpec(RemoteCommand command) {
    return switch (command) {
      RemoteCommand.netflix => ('Netflix', 'netflix'),
      RemoteCommand.primeVideo => ('Amazon', 'amazon'),
      RemoteCommand.disneyPlus => ('Disney+', 'disneyplus'),
      RemoteCommand.web => ('YouTube', 'youtube'),
      _ => null,
    };
  }
}
