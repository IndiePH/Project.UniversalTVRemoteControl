import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/data/multiplexed_tv_connection_state_service.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart'
    as remote_connection;
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';

void main() {
  const device = TvDevice(
    id: '192.168.1.10',
    displayName: 'Living Room',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands},
  );

  group('MultiplexedTvConnectionStateService', () {
    test('shares one upstream subscription across listeners', () async {
      final commandService = _RecordingCommandService();
      final service = MultiplexedTvConnectionStateService(
        commandService: commandService,
      );

      final statesA = <remote_connection.ConnectionState>[];
      final statesB = <remote_connection.ConnectionState>[];
      final subA = service.watch(device).listen(statesA.add);
      final subB = service.watch(device).listen(statesB.add);

      await Future<void>.delayed(Duration.zero);
      expect(commandService.watchConnectionStateCallCount, 1);

      commandService.emit(remote_connection.ConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      expect(statesA, contains(remote_connection.ConnectionState.connected));
      expect(statesB, contains(remote_connection.ConnectionState.connected));
      expect(
        service.stateFor(device.id),
        remote_connection.ConnectionState.connected,
      );

      await subA.cancel();
      await subB.cancel();
    });

    test('replays last known state to new listeners', () async {
      final commandService = _RecordingCommandService();
      final service = MultiplexedTvConnectionStateService(
        commandService: commandService,
      );

      final first = <remote_connection.ConnectionState>[];
      final firstSub = service.watch(device).listen(first.add);
      commandService.emit(remote_connection.ConnectionState.connecting);
      await Future<void>.delayed(Duration.zero);
      await firstSub.cancel();

      final second = <remote_connection.ConnectionState>[];
      service.watch(device).listen(second.add);
      await Future<void>.delayed(Duration.zero);

      expect(second.first, remote_connection.ConnectionState.connecting);
      expect(
        service.stateFor(device.id),
        remote_connection.ConnectionState.connecting,
      );
    });
  });
}

class _RecordingCommandService implements RemoteCommandService {
  int watchConnectionStateCallCount = 0;
  final StreamController<remote_connection.ConnectionState> _controller =
      StreamController<remote_connection.ConnectionState>.broadcast();

  void emit(remote_connection.ConnectionState state) => _controller.add(state);

  @override
  Stream<remote_connection.ConnectionState> watchConnectionState({
    required TvDevice device,
  }) {
    watchConnectionStateCallCount++;
    return _controller.stream;
  }

  @override
  Future<void> cancelPairing({required TvDevice device}) async {}

  @override
  Future<bool> checkRemoteTextInputReady({required TvDevice device}) async =>
      false;

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async =>
      CommandDispatchResult.success('ok');

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async =>
      CommandDispatchResult.success('ok');

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async =>
      CommandDispatchResult.success('ok');

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      const {};

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async =>
      CommandDispatchResult.success('ok');

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      Stream<bool>.value(false);

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;
}
