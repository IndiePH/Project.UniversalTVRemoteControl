import 'dart:async';
import 'dart:developer';

import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

class InMemoryRemoteCommandService implements RemoteCommandService {
  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async {
    log(
      'Mock preparePairing -> ${device.displayName}',
      name: 'remote_command_service',
    );
    return CommandDispatchResult.success(
      'Pairing approved for ${device.displayName}.',
    );
  }

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    log(
      'Mock submitPairingCode -> ${device.displayName}: $fourDigitPin',
      name: 'remote_command_service',
    );
    return CommandDispatchResult.success(
      'Pairing code accepted for ${device.displayName}.',
    );
  }

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    log(
      'Mock sendCommand -> ${device.displayName}: $command',
      name: 'remote_command_service',
    );
    return CommandDispatchResult.success('Sent: ${command.name}');
  }

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async {
    log(
      'Mock sendText -> ${device.displayName}: "$text"',
      name: 'remote_command_service',
    );
    return CommandDispatchResult.success('Text sent: "$text"');
  }

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      Stream<bool>.value(true);

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      RemoteCommand.values.toSet();

  @override
  Stream<ConnectionState> watchConnectionState({required TvDevice device}) =>
      Stream<ConnectionState>.value(ConnectionState.connected);
}
