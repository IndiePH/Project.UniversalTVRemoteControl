import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_app_launch.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_key_mapper.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

void main() {
  const mapper = SamsungKeyMapper();

  group('SamsungKeyMapper: keyCodesFor', () {
    test('returns KEY_POWER for power', () {
      expect(mapper.keyCodesFor(RemoteCommand.power), ['KEY_POWER']);
    });

    test('returns KEY_PLAYPAUSE for playPause', () {
      expect(mapper.keyCodesFor(RemoteCommand.playPause), ['KEY_PLAYPAUSE']);
    });

    test('returns KEY_VOLUP for volumeUp', () {
      expect(mapper.keyCodesFor(RemoteCommand.volumeUp), ['KEY_VOLUP']);
    });

    test('returns KEY_VOLDOWN for volumeDown', () {
      expect(mapper.keyCodesFor(RemoteCommand.volumeDown), ['KEY_VOLDOWN']);
    });

    test('returns KEY_CHUP for channelUp', () {
      expect(mapper.keyCodesFor(RemoteCommand.channelUp), ['KEY_CHUP']);
    });

    test('returns KEY_CHDOWN for channelDown', () {
      expect(mapper.keyCodesFor(RemoteCommand.channelDown), ['KEY_CHDOWN']);
    });

    test('returns KEY_MUTE for mute', () {
      expect(mapper.keyCodesFor(RemoteCommand.mute), ['KEY_MUTE']);
    });

    test('returns KEY_SOURCE for input', () {
      expect(mapper.keyCodesFor(RemoteCommand.input), ['KEY_SOURCE']);
    });

    test('returns launch key for web browser', () {
      expect(
        mapper.keyCodesFor(RemoteCommand.web),
        [samsungLaunchKeyFor(SamsungTizenAppIds.browser)],
      );
    });

    test('returns launch key for netflix', () {
      expect(
        mapper.keyCodesFor(RemoteCommand.netflix),
        [samsungLaunchKeyFor(SamsungTizenAppIds.netflix)],
      );
    });

    test('returns launch key for primeVideo', () {
      expect(
        mapper.keyCodesFor(RemoteCommand.primeVideo),
        [samsungLaunchKeyFor(SamsungTizenAppIds.primeVideo)],
      );
    });

    test('returns launch key for disneyPlus', () {
      expect(
        mapper.keyCodesFor(RemoteCommand.disneyPlus),
        [samsungLaunchKeyFor(SamsungTizenAppIds.disneyPlus)],
      );
    });

    test('returns launch key for youtube', () {
      expect(
        mapper.keyCodesFor(RemoteCommand.youtube),
        [samsungLaunchKeyFor(SamsungTizenAppIds.youtube)],
      );
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

    test('returns KEY_ENTER for dpadOk', () {
      expect(mapper.keyCodesFor(RemoteCommand.dpadOk), ['KEY_ENTER']);
    });

    test('returns KEY_RETURN for back', () {
      expect(mapper.keyCodesFor(RemoteCommand.back), ['KEY_RETURN']);
    });

    test('returns KEY_HOME for home', () {
      expect(mapper.keyCodesFor(RemoteCommand.home), ['KEY_HOME']);
    });

    test('returns multiple fallbacks for menu', () {
      expect(
        mapper.keyCodesFor(RemoteCommand.menu),
        ['KEY_MENU', 'KEY_SETTINGS', 'KEY_SETTING', 'KEY_OPTION'],
      );
    });

    test('every RemoteCommand value has a mapping', () {
      for (final command in RemoteCommand.values) {
        expect(
          mapper.keyCodesFor(command),
          isNotEmpty,
          reason: '${command.name} has no Samsung key mapping',
        );
      }
    });

    test('result is unmodifiable', () {
      final result = mapper.keyCodesFor(RemoteCommand.power);
      expect(() => (result).add('EXTRA'), throwsUnsupportedError);
    });
  });

}
