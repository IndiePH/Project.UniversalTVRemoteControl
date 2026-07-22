import 'package:flutter/services.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_command_interaction_category.dart';

/// Maps remote command categories to platform haptic feedback patterns.
enum RemoteHapticImpact { heavy, medium, light, selection }

/// Resolves the haptic impact for a command interaction category.
RemoteHapticImpact hapticImpactForCategory(
  RemoteCommandInteractionCategory category,
) {
  switch (category) {
    case RemoteCommandInteractionCategory.power:
      return RemoteHapticImpact.heavy;
    case RemoteCommandInteractionCategory.media:
      return RemoteHapticImpact.medium;
    case RemoteCommandInteractionCategory.volume:
    case RemoteCommandInteractionCategory.channel:
    case RemoteCommandInteractionCategory.system:
      return RemoteHapticImpact.light;
    case RemoteCommandInteractionCategory.navigation:
    case RemoteCommandInteractionCategory.appShortcut:
      return RemoteHapticImpact.selection;
  }
}

/// Plays category-aware haptic feedback for a remote command press.
final class RemoteCommandHapticFeedback {
  const RemoteCommandHapticFeedback._();

  static void playFor(RemoteCommand command) {
    playForCategory(command.interactionCategory);
  }

  static void playForCategory(RemoteCommandInteractionCategory category) {
    switch (hapticImpactForCategory(category)) {
      case RemoteHapticImpact.heavy:
        HapticFeedback.heavyImpact();
      case RemoteHapticImpact.medium:
        HapticFeedback.mediumImpact();
      case RemoteHapticImpact.light:
        HapticFeedback.lightImpact();
      case RemoteHapticImpact.selection:
        HapticFeedback.selectionClick();
    }
  }
}
