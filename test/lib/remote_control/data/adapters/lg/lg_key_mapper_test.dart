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
      mapper.payloadFor(RemoteCommand.channelUp),
      const KeySequence(['ssap://tv/channelUp']),
    );
    expect(
      mapper.payloadFor(RemoteCommand.channelDown),
      const KeySequence(['ssap://tv/channelDown']),
    );
  });

  test('LgKeyMapper: pointer commands return PointerCommand', () {
    expect(
      mapper.payloadFor(RemoteCommand.dpadUp),
      const PointerCommand('UP'),
    );
    expect(
      mapper.payloadFor(RemoteCommand.dpadDown),
      const PointerCommand('DOWN'),
    );
    expect(
      mapper.payloadFor(RemoteCommand.dpadLeft),
      const PointerCommand('LEFT'),
    );
    expect(
      mapper.payloadFor(RemoteCommand.dpadRight),
      const PointerCommand('RIGHT'),
    );
    expect(
      mapper.payloadFor(RemoteCommand.dpadOk),
      const PointerCommand('ENTER'),
    );
    expect(mapper.payloadFor(RemoteCommand.back), const PointerCommand('BACK'));
    expect(mapper.payloadFor(RemoteCommand.home), const PointerCommand('HOME'));
  });

  test('LgKeyMapper: power, mute, and playPause return ToggleCommand', () {
    expect(
      mapper.payloadFor(RemoteCommand.power),
      const ToggleCommand(ToggleKind.power),
    );
    expect(
      mapper.payloadFor(RemoteCommand.mute),
      const ToggleCommand(ToggleKind.mute),
    );
    expect(
      mapper.payloadFor(RemoteCommand.playPause),
      const ToggleCommand(ToggleKind.playPause),
    );
  });

  test('LgKeyMapper: app launches return AppLink with app ID', () {
    expect(mapper.payloadFor(RemoteCommand.netflix), const AppLink('netflix'));
    expect(
      mapper.payloadFor(RemoteCommand.primeVideo),
      const AppLink('amazon'),
    );
    expect(
      mapper.payloadFor(RemoteCommand.disneyPlus),
      const AppLink('disneyplus'),
    );
    expect(
      mapper.payloadFor(RemoteCommand.youtube),
      const AppLink('youtube.leanback.v4'),
    );
    expect(
      mapper.payloadFor(RemoteCommand.web),
      const AppLink('com.webos.app.browser'),
    );
  });

  test(
    'LgKeyMapper: menu returns the plain settings key (settings-app launch '
    'is dispatched separately by LgAdapter)',
    () {
      expect(
        mapper.payloadFor(RemoteCommand.menu),
        const KeySequence(['ssap://com.webos.service.settings/launchSettings']),
      );
    },
  );

  test('LgKeyMapper: all kCommonSupportedRemoteCommands are mapped', () {
    final unmapped = kCommonSupportedRemoteCommands
        .where((cmd) => mapper.payloadFor(cmd) == null)
        .toList();
    expect(unmapped, isEmpty, reason: 'Unmapped commands: $unmapped');
  });
}
