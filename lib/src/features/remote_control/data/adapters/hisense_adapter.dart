import 'dart:developer';

import 'package:one_remote/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

class HisenseAdapter implements TvBrandAdapter {
  HisenseAdapter({CommandKeyMap? keyMap})
    : _keyMap = keyMap ?? const _HisenseCommandKeyMap();

  @override
  TvBrand get brand => TvBrand.hisense;

  @override
  bool get supportsTextInput => false;

  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands;

  final CommandKeyMap _keyMap;

  @override
  Future<void> preparePairing({required TvDevice device}) async {}

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final keyCode = _keyMap.primaryKeyCodeFor(command) ?? command.name;
    log(
      'HisenseAdapter sendCommand -> ${device.displayName}: $command ($keyCode)',
      name: 'tv_brand_adapter',
    );
  }

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    log(
      'HisenseAdapter sendText -> ${device.displayName}: "$text"',
      name: 'tv_brand_adapter',
    );
  }
}

final class _HisenseCommandKeyMap extends CommandKeyMap {
  const _HisenseCommandKeyMap();

  @override
  List<String> keyCodesFor(RemoteCommand command) => <String>[command.name];
}
