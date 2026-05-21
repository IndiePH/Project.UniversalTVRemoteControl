import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';

/// Commands currently exposed in the shared remote UI.
const Set<RemoteCommand> kCommonSupportedRemoteCommands = {
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
