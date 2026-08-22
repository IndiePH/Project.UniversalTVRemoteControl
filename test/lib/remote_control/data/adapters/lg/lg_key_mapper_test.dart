import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

void main() {
  const mapper = LgKeyMapper();

  test('LgKeyMapper: SSAP commands return correct URIs', () {
    expect(
      mapper.payloadFor(RemoteCommand.volumeUp),
      const KeySequence(['ssap://audio/volumeUp']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.volumeDown),
      const KeySequence(['ssap://audio/volumeDown']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.power),
      const KeySequence([lgPowerToggleKey]),
    );
    expect(
      mapper.payloadFor(RemoteCommand.channelUp),
      const KeySequence(['ssap://tv/channelUp']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.channelDown),
      const KeySequence(['ssap://tv/channelDown']),
    );
  });

  test('LgKeyMapper: pointer commands return POINTER: sentinel', () {
    expect(
      mapper.payloadFor(RemoteCommand.dpadUp),
      const KeySequence(['${lgPointerPrefix}UP']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.dpadDown),
      const KeySequence(['${lgPointerPrefix}DOWN']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.dpadLeft),
      const KeySequence(['${lgPointerPrefix}LEFT']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.dpadRight),
      const KeySequence(['${lgPointerPrefix}RIGHT']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.dpadOk),
      const KeySequence(['${lgPointerPrefix}ENTER']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.back),
      const KeySequence(['${lgPointerPrefix}BACK']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.home),
      const KeySequence(['${lgPointerPrefix}HOME']),
    );
  });

  test('LgKeyMapper: power and playPause return toggle sentinels', () {
    expect(
      mapper.payloadFor(RemoteCommand.power),
      const KeySequence([lgPowerToggleKey]),
    );
    expect(
      mapper.payloadFor(RemoteCommand.playPause),
      const KeySequence([lgPlayPauseToggleKey]),
    );
  });

  test('LgKeyMapper: app launches return LAUNCH: sentinel with app ID', () {
    expect(
      mapper.payloadFor(RemoteCommand.netflix),
      const KeySequence(['${lgLaunchPrefix}netflix']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.primeVideo),
      const KeySequence(['${lgLaunchPrefix}amazon']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.disneyPlus),
      const KeySequence(['${lgLaunchPrefix}disneyplus']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.web),
      const KeySequence(['${lgLaunchPrefix}com.webos.app.browser']),
    );
  });

  test('LgKeyMapper: menu returns fallback settings entry points', () {
    expect(
      mapper.payloadFor(RemoteCommand.menu),
      const KeySequence([
        'ssap://com.webos.service.settings/launchSettings',
        '${lgLaunchPrefix}com.webos.app.settings',
      ]),
    );
  });

  test('LgKeyMapper: all kCommonSupportedRemoteCommands are mapped', () {
    final unmapped = kCommonSupportedRemoteCommands
        .where((cmd) => mapper.payloadFor(cmd) == null)
        .toList();
    expect(unmapped, isEmpty, reason: 'Unmapped commands: $unmapped');
  });
}
