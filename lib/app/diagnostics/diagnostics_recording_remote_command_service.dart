import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Records pairing and command dispatch outcomes for the diagnostics dashboard.
final class DiagnosticsRecordingRemoteCommandService
    implements RemoteCommandService {
  const DiagnosticsRecordingRemoteCommandService({
    required RemoteCommandService delegate,
    required AppDiagnosticsRecorder recorder,
  }) : _delegate = delegate,
       _recorder = recorder;

  final RemoteCommandService _delegate;
  final AppDiagnosticsRecorder _recorder;

  @override
  Future<void> cancelPairing({required TvDevice device}) =>
      _delegate.cancelPairing(device: device);

  @override
  Future<bool> checkRemoteTextInputReady({required TvDevice device}) =>
      _delegate.checkRemoteTextInputReady(device: device);

  @override
  Future<CommandDispatchResult> preparePairing({required TvDevice device}) async {
    final result = await _delegate.preparePairing(device: device);
    _recorder.recordPairingDispatch(
      phase: 'prepare',
      outcome: result.getOutcome(),
      brand: device.brand,
    );
    return result;
  }

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final result = await _delegate.sendCommand(
      device: device,
      command: command,
    );
    _recorder.recordCommandDispatch(
      outcome: result.getOutcome(),
      brand: device.brand,
      action: command.name,
    );
    return result;
  }

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async {
    final result = await _delegate.sendText(device: device, text: text);
    _recorder.recordCommandDispatch(
      outcome: result.getOutcome(),
      brand: device.brand,
      action: 'sendText',
    );
    return result;
  }

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      _delegate.supportedCommandsFor(device: device);

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) async {
    final result = await _delegate.submitPairingCode(
      device: device,
      pinCode: pinCode,
    );
    _recorder.recordPairingDispatch(
      phase: 'submitPin',
      outcome: result.getOutcome(),
      brand: device.brand,
    );
    return result;
  }

  @override
  Future<void> unpairDevice({required TvDevice device}) =>
      _delegate.unpairDevice(device: device);

  @override
  Stream<ConnectionState> watchConnectionState({required TvDevice device}) =>
      _delegate.watchConnectionState(device: device);

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      _delegate.watchRemoteTextInputReady(device: device);
}
