import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract class RemoteCommandService {
  Future<CommandDispatchResult> preparePairing({required TvDevice device});

  /// Clears persisted pairing credentials for [device]. Call before removing
  /// the device from the repository so re-pairing shows the TV prompt again.
  Future<void> unpairDevice({required TvDevice device});

  /// Cancels an in-progress pairing attempt. Safe to call when no pairing is
  /// active. No-op for brands with no blocking transport state.
  Future<void> cancelPairing({required TvDevice device});

  /// Submit a brand-specific pairing code shown on the TV (e.g. Hisense PIN or Android TV hex code).
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  });

  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  });

  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  });

  Set<RemoteCommand> supportedCommandsFor({required TvDevice device});

  /// Whether the TV UI is ready to accept remote-typed text (brand-specific; e.g. Samsung IME).
  Stream<bool> watchRemoteTextInputReady({required TvDevice device});

  /// One-shot check used by keyboard-button interactions before opening text UI.
  Future<bool> checkRemoteTextInputReady({required TvDevice device});

  /// Normalized remote connection state for the selected TV session.
  Stream<ConnectionState> watchConnectionState({required TvDevice device});

  /// Cached or probed model/firmware from the active transport (brand-dependent).
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device});
}
