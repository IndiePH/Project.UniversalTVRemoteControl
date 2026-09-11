import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:one_remote/remote_control/application/application.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/domain/domain.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_data.dart';

/// Phase of [ReconnectionRetryController]'s cycle. See
/// `references/goals/goal-automatic-reconnection-resilience.md` SG1/T1.1-T1.2.
enum ReconnectionPhase { fastRetry, escalating, waiting }

/// Snapshot published on [ReconnectionRetryController.stateNotifier]. The
/// notifier itself is `null` while the controller is idle (never started, or
/// stopped).
@immutable
class ReconnectionRetryState {
  const ReconnectionRetryState({
    required this.phase,
    this.waitSecondsRemaining = 0,
  });

  final ReconnectionPhase phase;
  final int waitSecondsRemaining;
}

/// Drives the fast → escalate → wait → repeat reconnection cycle used by
/// `RemoteHomePage` whenever its active device is disconnected while the page
/// is open.
///
/// Kept independent of any widget (per clean-code-solid SRP) so the cycle's
/// timing and escalation logic can be reasoned about — and tested — without a
/// widget tree. `RemoteHomePage` owns one instance, starts/stops it as
/// connection state changes, and listens to [stateNotifier] to render the
/// wait-phase countdown and retry-now action.
class ReconnectionRetryController {
  ReconnectionRetryController({
    required this._commandService,
    required this._discoveryService,
    required this._deviceRepository,
    required this._identityRegistry,
    required this._layoutRepository,
    required this._canAttemptNow,
    required this._onDeviceUpdated,
    this.fastAttemptLimit = 3,
    this.fastAttemptInterval = const Duration(seconds: 5),
    this.waitDuration = const Duration(seconds: 45),
    this.waitGrowthFactor = 2,
    this.waitCap = const Duration(minutes: 5),
  });

  final RemoteCommandService _commandService;
  final DeviceDiscoveryService _discoveryService;
  final DeviceRepository _deviceRepository;
  final DeviceIdentityRegistry? _identityRegistry;
  final LayoutRepository? _layoutRepository;
  final bool Function() _canAttemptNow;
  final void Function(TvDevice device) _onDeviceUpdated;

  /// Number of connect attempts made in the fast phase before escalating.
  final int fastAttemptLimit;

  /// Delay between fast-phase connect attempts.
  final Duration fastAttemptInterval;

  /// The wait phase's duration on the first lap of a disconnected streak.
  /// Grows by [waitGrowthFactor] on each subsequent lap (see
  /// [_nextWaitDuration]), up to [waitCap]. Resets back to this value
  /// whenever [start] begins a fresh streak or [retryNow] is used — see
  /// `references/goals/goal-automatic-reconnection-resilience.md` SG1/T1.2.
  final Duration waitDuration;

  /// Multiplier applied to the wait duration after each failed lap.
  final int waitGrowthFactor;

  /// Ceiling the wait duration never grows past, however many laps fail in a
  /// row — bounds worst-case retry spacing for a genuinely long-absent
  /// device.
  final Duration waitCap;

  /// `null` while idle; otherwise the current phase/countdown. Safe to listen
  /// to across the controller's lifetime — replaced on [dispose], not closed
  /// until then.
  final ValueNotifier<ReconnectionRetryState?> stateNotifier = ValueNotifier(
    null,
  );

  TvDevice? _device;
  Timer? _timer;
  int _fastAttemptsMade = 0;

  /// The duration [_beginWaitPhase] will use the *next* time it runs. Reset
  /// to [waitDuration] by [start] (a fresh disconnected streak) and
  /// [retryNow] (the user asked for a fresh attempt); grown by
  /// [waitGrowthFactor], capped at [waitCap], every other time a lap's wait
  /// phase actually begins. Always assigned before [_beginWaitPhase] can run
  /// — [start] runs first in every path that reaches it.
  late Duration _nextWaitDuration;

  /// Starts the fast phase for [device]. No-op if a cycle is already running
  /// — call [stop] first to restart from scratch with a different device.
  void start(TvDevice device) {
    if (_timer != null) return;
    _device = device;
    _nextWaitDuration = waitDuration;
    _beginFastPhase();
  }

  /// Cancels any pending timer and returns the controller to idle.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _device = null;
    _fastAttemptsMade = 0;
    stateNotifier.value = null;
  }

  /// Cancels a pending wait and fires a connect attempt immediately — rather
  /// than just resetting the wait clock — then resumes the fast phase from
  /// there. No-op while idle.
  void retryNow() {
    if (_device == null) return;
    _timer?.cancel();
    _fastAttemptsMade = 0;
    _nextWaitDuration = waitDuration;
    stateNotifier.value = const ReconnectionRetryState(
      phase: ReconnectionPhase.fastRetry,
    );
    _attemptFastConnect();
    _timer = Timer.periodic(fastAttemptInterval, (_) => _attemptFastConnect());
  }

  /// Releases the state notifier. The controller is unusable afterward.
  void dispose() {
    _timer?.cancel();
    stateNotifier.dispose();
  }

  void _beginFastPhase() {
    _fastAttemptsMade = 0;
    stateNotifier.value = const ReconnectionRetryState(
      phase: ReconnectionPhase.fastRetry,
    );
    _timer = Timer.periodic(fastAttemptInterval, (_) => _attemptFastConnect());
  }

  void _attemptFastConnect() {
    // Skip (not count) this tick while another route is on top — avoids
    // dialing the active TV mid-pairing-flow. Resumes naturally once this
    // page is current again, matching the pre-existing retry timer's
    // behavior.
    if (!_canAttemptNow()) return;
    _fastAttemptsMade++;
    _fireConnect();
    if (_fastAttemptsMade >= fastAttemptLimit) {
      _timer?.cancel();
      unawaited(_runEscalation());
    }
  }

  Future<void> _runEscalation() async {
    final device = _device;
    if (device == null) return;
    stateNotifier.value = const ReconnectionRetryState(
      phase: ReconnectionPhase.escalating,
    );
    if (_canAttemptNow()) {
      try {
        final discovered = await PairingPageData.discoverDevices(
          _discoveryService,
        );
        final saved = await _deviceRepository.getSavedDevices();
        await PairingPageData.reconcileDiscovery(
          discovered: discovered,
          saved: saved,
          identityRegistry: _identityRegistry,
          deviceRepository: _deviceRepository,
          layoutRepository: _layoutRepository,
        );
        await _refreshDeviceFromRepository(device);
      } catch (_) {
        // Best-effort: a failed discovery/reconcile pass falls through to
        // the wait phase below and tries again next lap, rather than
        // blocking the cycle.
      }
    }
    if (_device == null) return; // stopped while escalating
    if (_canAttemptNow()) {
      _fireConnect();
    }
    _beginWaitPhase();
  }

  /// Re-reads [device] from the repository after a reconciliation pass and,
  /// if its host changed, adopts the refreshed copy for this controller's own
  /// next connect attempt and reports it via [_onDeviceUpdated] so the owning
  /// page's copy (e.g. `RemoteHomePage._activeDevice`) doesn't keep
  /// addressing the stale host.
  Future<void> _refreshDeviceFromRepository(TvDevice device) async {
    final saved = await _deviceRepository.getSavedDevices();
    for (final candidate in saved) {
      if (candidate.id != device.id) continue;
      if (candidate.resolvedHost != device.resolvedHost) {
        _device = candidate;
        _onDeviceUpdated(candidate);
      }
      return;
    }
  }

  void _beginWaitPhase() {
    var remaining = _nextWaitDuration.inSeconds;
    stateNotifier.value = ReconnectionRetryState(
      phase: ReconnectionPhase.waiting,
      waitSecondsRemaining: remaining,
    );
    _nextWaitDuration = _grow(_nextWaitDuration);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      remaining--;
      if (remaining <= 0) {
        _timer?.cancel();
        _beginFastPhase();
        return;
      }
      stateNotifier.value = ReconnectionRetryState(
        phase: ReconnectionPhase.waiting,
        waitSecondsRemaining: remaining,
      );
    });
  }

  Duration _grow(Duration current) {
    final grown = current * waitGrowthFactor;
    return grown > waitCap ? waitCap : grown;
  }

  void _fireConnect() {
    final device = _device;
    if (device == null) return;
    unawaited(_commandService.connect(device: device));
  }
}
