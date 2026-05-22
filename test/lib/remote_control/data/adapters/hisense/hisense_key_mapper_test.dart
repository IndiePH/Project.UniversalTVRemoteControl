import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_key_mapper.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

void main() {
  const mapper = HisenseKeyMapper();

  group('HisenseKeyMapper: keyCodesFor', () {
    test('returns KEY_POWER for power', () {
      expect(mapper.keyCodesFor(RemoteCommand.power), ['KEY_POWER']);
    });

    test('returns multiple fallbacks for playPause', () {
      expect(mapper.keyCodesFor(RemoteCommand.playPause), [
        'KEY_PLAYPAUSE',
        'KEY_PLAY',
      ]);
    });

    test('returns KEY_VOLUMEUP for volumeUp', () {
      expect(mapper.keyCodesFor(RemoteCommand.volumeUp), ['KEY_VOLUMEUP']);
    });

    test('returns KEY_VOLUMEDOWN for volumeDown', () {
      expect(mapper.keyCodesFor(RemoteCommand.volumeDown), ['KEY_VOLUMEDOWN']);
    });

    test('returns multiple fallbacks for channelUp', () {
      expect(mapper.keyCodesFor(RemoteCommand.channelUp), [
        'KEY_CHANNELUP',
        'KEY_CHSUP',
      ]);
    });

    test('returns multiple fallbacks for channelDown', () {
      expect(mapper.keyCodesFor(RemoteCommand.channelDown), [
        'KEY_CHANNELDOWN',
        'KEY_CHSDOWN',
      ]);
    });

    test('returns KEY_MUTE for mute', () {
      expect(mapper.keyCodesFor(RemoteCommand.mute), ['KEY_MUTE']);
    });

    test('returns multiple fallbacks for input', () {
      expect(mapper.keyCodesFor(RemoteCommand.input), [
        'KEY_SOURCE',
        'KEY_INPUT',
      ]);
    });

    test('returns KEY_UP for dpadUp', () {
      expect(mapper.keyCodesFor(RemoteCommand.dpadUp), ['KEY_UP']);
    });

    test('returns KEY_DOWN for dpadDown', () {
      expect(mapper.keyCodesFor(RemoteCommand.dpadDown), ['KEY_DOWN']);
    });

    test('returns KEY_LEFT for dpadLeft', () {
      expect(mapper.keyCodesFor(RemoteCommand.dpadLeft), ['KEY_LEFT']);
    });

    test('returns KEY_RIGHT for dpadRight', () {
      expect(mapper.keyCodesFor(RemoteCommand.dpadRight), ['KEY_RIGHT']);
    });

    test('returns KEY_OK for dpadOk', () {
      expect(mapper.keyCodesFor(RemoteCommand.dpadOk), ['KEY_OK']);
    });

    test('returns multiple fallbacks for back', () {
      expect(mapper.keyCodesFor(RemoteCommand.back), [
        'KEY_RETURNS',
        'KEY_RETURN',
        'KEY_BACK',
      ]);
    });

    test('returns KEY_HOME for home', () {
      expect(mapper.keyCodesFor(RemoteCommand.home), ['KEY_HOME']);
    });

    test('returns multiple fallbacks for menu', () {
      expect(mapper.keyCodesFor(RemoteCommand.menu), [
        'KEY_MENU',
        'KEY_SETTINGS',
        'KEY_SETTING',
        'KEY_OPTION',
      ]);
    });
  });

  group(
    'HisenseKeyMapper: app-launch commands return empty (handled via launchVidaaApp)',
    () {
      test('web returns empty', () {
        expect(mapper.keyCodesFor(RemoteCommand.web), isEmpty);
      });

      test('netflix returns empty', () {
        expect(mapper.keyCodesFor(RemoteCommand.netflix), isEmpty);
      });

      test('primeVideo returns empty', () {
        expect(mapper.keyCodesFor(RemoteCommand.primeVideo), isEmpty);
      });

      test('disneyPlus returns empty', () {
        expect(mapper.keyCodesFor(RemoteCommand.disneyPlus), isEmpty);
      });

      test('primaryKeyCodeFor returns null for all app-launch commands', () {
        for (final command in [
          RemoteCommand.web,
          RemoteCommand.netflix,
          RemoteCommand.primeVideo,
          RemoteCommand.disneyPlus,
        ]) {
          expect(
            mapper.primaryKeyCodeFor(command),
            isNull,
            reason: '${command.name} should have no primary key code',
          );
        }
      });
    },
  );

  group('HisenseKeyMapper: primaryKeyCodeFor', () {
    test('returns first key for commands with multiple fallbacks', () {
      expect(
        mapper.primaryKeyCodeFor(RemoteCommand.playPause),
        'KEY_PLAYPAUSE',
      );
      expect(mapper.primaryKeyCodeFor(RemoteCommand.back), 'KEY_RETURNS');
      expect(
        mapper.primaryKeyCodeFor(RemoteCommand.channelUp),
        'KEY_CHANNELUP',
      );
    });

    test('returns the single key for single-mapping commands', () {
      expect(mapper.primaryKeyCodeFor(RemoteCommand.power), 'KEY_POWER');
      expect(mapper.primaryKeyCodeFor(RemoteCommand.mute), 'KEY_MUTE');
    });
  });
}
