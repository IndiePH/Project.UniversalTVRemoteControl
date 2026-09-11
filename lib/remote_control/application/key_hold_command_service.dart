import 'package:one_remote/remote_control/domain/models/key_hold_phase.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Opt-in application port for [RemoteCommandService] implementations that can
/// dispatch a held-key press (see `TvBrandAdapter.supportsKeyHold`). Kept
/// separate from `RemoteCommandService` itself, mirroring
/// [TransportLogReaderProvider]'s shape, so unrelated stub/test
/// implementations of `RemoteCommandService` are not forced to implement hold
/// support they will never exercise — see
/// `references/goals/goal-long-press-key.md`.
abstract interface class KeyHoldCommandService {
  /// Whether [device]'s brand/variant can send a real held-key press.
  bool supportsKeyHold({required TvDevice device});

  /// Sends one edge (`down` or `up`) of a held key press. Throws if
  /// [supportsKeyHold] would return `false` for [device] — callers must check
  /// first, same contract as `TvBrandAdapter.sendKeyHold`.
  Future<void> sendKeyHold({
    required TvDevice device,
    required RemoteCommand command,
    required KeyHoldPhase phase,
  });
}

/// No-op fallback used when no provider is configured.
final class NoopKeyHoldCommandService implements KeyHoldCommandService {
  const NoopKeyHoldCommandService();

  @override
  bool supportsKeyHold({required TvDevice device}) => false;

  @override
  Future<void> sendKeyHold({
    required TvDevice device,
    required RemoteCommand command,
    required KeyHoldPhase phase,
  }) async => throw UnsupportedError('Key hold is not supported.');
}
