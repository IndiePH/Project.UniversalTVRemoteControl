import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';

void main() {
  const mapper = LgKeyMapper();

  test('LgKeyMapper: SSAP commands return correct URIs', () {
    expect(mapper.primaryKeyCodeFor(RemoteCommand.volumeUp), 'ssap://audio/volumeUp');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.volumeDown), 'ssap://audio/volumeDown');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.power), lgPowerToggleKey);
    expect(mapper.primaryKeyCodeFor(RemoteCommand.channelUp), 'ssap://tv/channelUp');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.channelDown), 'ssap://tv/channelDown');
  });

  test('LgKeyMapper: pointer commands return POINTER: sentinel', () {
    expect(mapper.primaryKeyCodeFor(RemoteCommand.dpadUp), '${lgPointerPrefix}UP');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.dpadDown), '${lgPointerPrefix}DOWN');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.dpadLeft), '${lgPointerPrefix}LEFT');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.dpadRight), '${lgPointerPrefix}RIGHT');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.dpadOk), '${lgPointerPrefix}ENTER');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.back), '${lgPointerPrefix}BACK');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.home), '${lgPointerPrefix}HOME');
  });

  test('LgKeyMapper: power and playPause return toggle sentinels', () {
    expect(mapper.primaryKeyCodeFor(RemoteCommand.power), lgPowerToggleKey);
    expect(mapper.primaryKeyCodeFor(RemoteCommand.playPause), lgPlayPauseToggleKey);
  });

  test('LgKeyMapper: app launches return LAUNCH: sentinel with app ID', () {
    expect(mapper.primaryKeyCodeFor(RemoteCommand.netflix), '${lgLaunchPrefix}netflix');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.primeVideo), '${lgLaunchPrefix}amazon');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.disneyPlus), '${lgLaunchPrefix}disneyplus');
    expect(mapper.primaryKeyCodeFor(RemoteCommand.web), '${lgLaunchPrefix}com.webos.app.browser');
  });

  test('LgKeyMapper: menu is unsupported (not mapped)', () {
    expect(mapper.primaryKeyCodeFor(RemoteCommand.menu), isNull);
    expect(mapper.keyCodesFor(RemoteCommand.menu), isEmpty);
  });

  test('LgKeyMapper: all kCommonSupportedRemoteCommands except menu are mapped', () {
    final unmapped = kCommonSupportedRemoteCommands
        .where((cmd) => cmd != RemoteCommand.menu)
        .where((cmd) => mapper.primaryKeyCodeFor(cmd) == null)
        .toList();
    expect(unmapped, isEmpty, reason: 'Unmapped commands: $unmapped');
  });
}
