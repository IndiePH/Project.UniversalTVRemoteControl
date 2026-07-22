import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_command_haptic_feedback.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_command_interaction_category.dart';

void main() {
  group('RemoteCommandInteractionCategoryX', () {
    test('maps power to power category', () {
      expect(
        RemoteCommand.power.interactionCategory,
        RemoteCommandInteractionCategory.power,
      );
    });

    test('maps d-pad commands to navigation category', () {
      for (final command in [
        RemoteCommand.dpadUp,
        RemoteCommand.dpadDown,
        RemoteCommand.dpadLeft,
        RemoteCommand.dpadRight,
        RemoteCommand.dpadOk,
      ]) {
        expect(
          command.interactionCategory,
          RemoteCommandInteractionCategory.navigation,
        );
      }
    });

    test('maps streaming shortcuts to appShortcut category', () {
      for (final command in [
        RemoteCommand.netflix,
        RemoteCommand.primeVideo,
        RemoteCommand.disneyPlus,
        RemoteCommand.youtube,
      ]) {
        expect(
          command.interactionCategory,
          RemoteCommandInteractionCategory.appShortcut,
        );
      }
    });
  });

  group('hapticImpactForCategory', () {
    test('uses heavier impact for power and media', () {
      expect(
        hapticImpactForCategory(RemoteCommandInteractionCategory.power),
        RemoteHapticImpact.heavy,
      );
      expect(
        hapticImpactForCategory(RemoteCommandInteractionCategory.media),
        RemoteHapticImpact.medium,
      );
    });

    test('uses selection click for navigation and app shortcuts', () {
      expect(
        hapticImpactForCategory(RemoteCommandInteractionCategory.navigation),
        RemoteHapticImpact.selection,
      );
      expect(
        hapticImpactForCategory(RemoteCommandInteractionCategory.appShortcut),
        RemoteHapticImpact.selection,
      );
    });

    test('uses light impact for volume, channel, and system controls', () {
      for (final category in [
        RemoteCommandInteractionCategory.volume,
        RemoteCommandInteractionCategory.channel,
        RemoteCommandInteractionCategory.system,
      ]) {
        expect(hapticImpactForCategory(category), RemoteHapticImpact.light);
      }
    });
  });
}
