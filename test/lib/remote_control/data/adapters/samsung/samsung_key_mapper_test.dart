import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_app_launch.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_key_mapper.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

void main() {
  const mapper = SamsungKeyMapper();

  group('SamsungKeyMapper: payloadFor', () {
    test('returns KEY_POWER for power', () {
      expect(
        mapper.payloadFor(RemoteCommand.power),
        const KeySequence(['KEY_POWER']),
      );
    });

    test('returns KEY_PLAYPAUSE for playPause', () {
      expect(
        mapper.payloadFor(RemoteCommand.playPause),
        const KeySequence(['KEY_PLAYPAUSE']),
      );
    });

    test('returns KEY_VOLUP for volumeUp', () {
      expect(
        mapper.payloadFor(RemoteCommand.volumeUp),
        const KeySequence(['KEY_VOLUP']),
      );
    });

    test('returns KEY_VOLDOWN for volumeDown', () {
      expect(
        mapper.payloadFor(RemoteCommand.volumeDown),
        const KeySequence(['KEY_VOLDOWN']),
      );
    });

    test('returns KEY_CHUP for channelUp', () {
      expect(
        mapper.payloadFor(RemoteCommand.channelUp),
        const KeySequence(['KEY_CHUP']),
      );
    });

    test('returns KEY_CHDOWN for channelDown', () {
      expect(
        mapper.payloadFor(RemoteCommand.channelDown),
        const KeySequence(['KEY_CHDOWN']),
      );
    });

    test('returns KEY_MUTE for mute', () {
      expect(
        mapper.payloadFor(RemoteCommand.mute),
        const KeySequence(['KEY_MUTE']),
      );
    });

    test('returns KEY_SOURCE for input', () {
      expect(
        mapper.payloadFor(RemoteCommand.input),
        const KeySequence(['KEY_SOURCE']),
      );
    });

    test('returns an AppLink for web browser', () {
      expect(
        mapper.payloadFor(RemoteCommand.web),
        const AppLink(SamsungTizenAppIds.browser),
      );
    });

    test('returns an AppLink for netflix', () {
      expect(
        mapper.payloadFor(RemoteCommand.netflix),
        const AppLink(SamsungTizenAppIds.netflix),
      );
    });

    test('returns an AppLink for primeVideo', () {
      expect(
        mapper.payloadFor(RemoteCommand.primeVideo),
        const AppLink(SamsungTizenAppIds.primeVideo),
      );
    });

    test('returns an AppLink for disneyPlus', () {
      expect(
        mapper.payloadFor(RemoteCommand.disneyPlus),
        const AppLink(SamsungTizenAppIds.disneyPlus),
      );
    });

    test('returns an AppLink for youtube', () {
      expect(
        mapper.payloadFor(RemoteCommand.youtube),
        const AppLink(SamsungTizenAppIds.youtube),
      );
    });

    test('returns KEY_UP for dpadUp', () {
      expect(
        mapper.payloadFor(RemoteCommand.dpadUp),
        const KeySequence(['KEY_UP']),
      );
    });

    test('returns KEY_DOWN for dpadDown', () {
      expect(
        mapper.payloadFor(RemoteCommand.dpadDown),
        const KeySequence(['KEY_DOWN']),
      );
    });

    test('returns KEY_LEFT for dpadLeft', () {
      expect(
        mapper.payloadFor(RemoteCommand.dpadLeft),
        const KeySequence(['KEY_LEFT']),
      );
    });

    test('returns KEY_RIGHT for dpadRight', () {
      expect(
        mapper.payloadFor(RemoteCommand.dpadRight),
        const KeySequence(['KEY_RIGHT']),
      );
    });

    test('returns KEY_ENTER for dpadOk', () {
      expect(
        mapper.payloadFor(RemoteCommand.dpadOk),
        const KeySequence(['KEY_ENTER']),
      );
    });

    test('returns back aliases in firmware-tolerant order', () {
      expect(
        mapper.payloadFor(RemoteCommand.back),
        const KeySequence(['KEY_RETURN', 'KEY_BACK']),
      );
    });

    test('returns KEY_HOME for home', () {
      expect(
        mapper.payloadFor(RemoteCommand.home),
        const KeySequence(['KEY_HOME']),
      );
    });

    test('returns multiple fallbacks for menu', () {
      expect(
        mapper.payloadFor(RemoteCommand.menu),
        const KeySequence([
          'KEY_MENU',
          'KEY_SETTINGS',
          'KEY_SETTING',
          'KEY_OPTION',
        ]),
      );
    });

    test('every RemoteCommand value has a mapping', () {
      for (final command in RemoteCommand.values) {
        expect(
          mapper.payloadFor(command),
          isNotNull,
          reason: '${command.name} has no Samsung mapping',
        );
      }
    });

    test('KeySequence codes are unmodifiable', () {
      final payload = mapper.payloadFor(RemoteCommand.power);
      final codes = (payload as KeySequence).codes;
      expect(() => codes.add('EXTRA'), throwsUnsupportedError);
    });
  });
}
