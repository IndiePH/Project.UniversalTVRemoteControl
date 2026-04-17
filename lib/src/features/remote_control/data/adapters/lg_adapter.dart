import 'dart:developer';

import 'package:one_remote/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

class LgAdapter implements TvBrandAdapter {
  LgAdapter({
    CommandKeyMap? keyMap,
  }) : _keyMap = keyMap ?? const _LgCommandKeyMap();

  @override
  TvBrand get brand => TvBrand.lg;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands;

  final CommandKeyMap _keyMap;

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final keyCode = _keyMap.primaryKeyCodeFor(command) ?? command.name;
    log(
      'LgAdapter sendCommand -> ${device.displayName}: $command ($keyCode)',
      name: 'tv_brand_adapter',
    );
  }

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    log(
      'LgAdapter sendText -> ${device.displayName}: "$text"',
      name: 'tv_brand_adapter',
    );
  }
}

final class _LgCommandKeyMap extends CommandKeyMap {
  const _LgCommandKeyMap();

  @override
  List<String> keyCodesFor(RemoteCommand command) => <String>[command.name];
}
