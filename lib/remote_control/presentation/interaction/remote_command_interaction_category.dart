import 'package:one_remote/remote_control/domain/models/remote_command.dart';

/// Groups [RemoteCommand] values for differentiated interaction feedback.
enum RemoteCommandInteractionCategory {
  power,
  navigation,
  media,
  volume,
  channel,
  system,
  appShortcut,
}

/// Resolves the interaction category used for haptic feedback intensity.
extension RemoteCommandInteractionCategoryX on RemoteCommand {
  RemoteCommandInteractionCategory get interactionCategory {
    switch (this) {
      case RemoteCommand.power:
        return RemoteCommandInteractionCategory.power;
      case RemoteCommand.dpadUp:
      case RemoteCommand.dpadDown:
      case RemoteCommand.dpadLeft:
      case RemoteCommand.dpadRight:
      case RemoteCommand.dpadOk:
        return RemoteCommandInteractionCategory.navigation;
      case RemoteCommand.playPause:
        return RemoteCommandInteractionCategory.media;
      case RemoteCommand.volumeUp:
      case RemoteCommand.volumeDown:
      case RemoteCommand.mute:
        return RemoteCommandInteractionCategory.volume;
      case RemoteCommand.channelUp:
      case RemoteCommand.channelDown:
        return RemoteCommandInteractionCategory.channel;
      case RemoteCommand.back:
      case RemoteCommand.home:
      case RemoteCommand.menu:
      case RemoteCommand.input:
      case RemoteCommand.web:
        return RemoteCommandInteractionCategory.system;
      case RemoteCommand.netflix:
      case RemoteCommand.primeVideo:
      case RemoteCommand.disneyPlus:
      case RemoteCommand.youtube:
        return RemoteCommandInteractionCategory.appShortcut;
    }
  }
}
