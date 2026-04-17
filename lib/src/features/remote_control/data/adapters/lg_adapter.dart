import 'dart:developer';

import 'package:universal_tv_remove_control/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/remote_command.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_device.dart';

class LgAdapter implements TvBrandAdapter {
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
  TvBrand get brand => TvBrand.lg;

  @override
  bool get supportsTextInput => true;

  @override
  Set<RemoteCommand> get supportedCommands => _supportedCommands;

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    log(
      'LgAdapter sendCommand -> ${device.displayName}: $command',
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
