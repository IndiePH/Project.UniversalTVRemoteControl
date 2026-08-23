import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_key_mapper.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

void main() {
  const mapper = HisenseKeyMapper();

  group('HisenseKeyMapper: payloadFor (key commands)', () {
    test('returns KEY_POWER for power', () {
      expect(
        mapper.payloadFor(RemoteCommand.power),
        const KeySequence(['KEY_POWER']),
      );
    });

    test('returns multiple fallbacks for playPause', () {
      expect(
        mapper.payloadFor(RemoteCommand.playPause),
        const KeySequence(['KEY_PLAYPAUSE', 'KEY_PLAY']),
      );
    });

    test('returns KEY_VOLUMEUP for volumeUp', () {
      expect(
        mapper.payloadFor(RemoteCommand.volumeUp),
        const KeySequence(['KEY_VOLUMEUP']),
      );
    });

    test('returns KEY_VOLUMEDOWN for volumeDown', () {
      expect(
        mapper.payloadFor(RemoteCommand.volumeDown),
        const KeySequence(['KEY_VOLUMEDOWN']),
      );
    });

    test('returns multiple fallbacks for channelUp', () {
      expect(
        mapper.payloadFor(RemoteCommand.channelUp),
        const KeySequence(['KEY_CHANNELUP', 'KEY_CHSUP']),
      );
    });

    test('returns multiple fallbacks for channelDown', () {
      expect(
        mapper.payloadFor(RemoteCommand.channelDown),
        const KeySequence(['KEY_CHANNELDOWN', 'KEY_CHSDOWN']),
      );
    });

    test('returns KEY_MUTE for mute', () {
      expect(
        mapper.payloadFor(RemoteCommand.mute),
        const KeySequence(['KEY_MUTE']),
      );
    });

    test('returns multiple fallbacks for input', () {
      expect(
        mapper.payloadFor(RemoteCommand.input),
        const KeySequence(['KEY_SOURCE', 'KEY_INPUT']),
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

    test('returns KEY_OK for dpadOk', () {
      expect(
        mapper.payloadFor(RemoteCommand.dpadOk),
        const KeySequence(['KEY_OK']),
      );
    });

    test('returns multiple fallbacks for back', () {
      expect(
        mapper.payloadFor(RemoteCommand.back),
        const KeySequence(['KEY_RETURNS', 'KEY_RETURN', 'KEY_BACK']),
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
  });

  group('HisenseKeyMapper: payloadFor (app-launch commands)', () {
    test('web returns a VidaaLaunch', () {
      expect(
        mapper.payloadFor(RemoteCommand.web),
        const VidaaLaunch('YouTube', 'youtube'),
      );
    });

    test('netflix returns a VidaaLaunch', () {
      expect(
        mapper.payloadFor(RemoteCommand.netflix),
        const VidaaLaunch('Netflix', 'netflix'),
      );
    });

    test('primeVideo returns a VidaaLaunch', () {
      expect(
        mapper.payloadFor(RemoteCommand.primeVideo),
        const VidaaLaunch('Amazon', 'amazon'),
      );
    });

    test('disneyPlus returns a VidaaLaunch', () {
      expect(
        mapper.payloadFor(RemoteCommand.disneyPlus),
        const VidaaLaunch('Disney+', 'disneyplus'),
      );
    });

    test('youtube returns a VidaaLaunch', () {
      expect(
        mapper.payloadFor(RemoteCommand.youtube),
        const VidaaLaunch('YouTube', 'youtube'),
      );
    });
  });
}
