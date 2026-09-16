import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/data/in_memory_device_repository.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import 'package:one_remote/remote_control/presentation/controllers/reconnection_retry_controller.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_data.dart';

TvDevice _device({required String id, required String host}) => TvDevice(
  id: id,
  displayName: 'Living Room TV',
  brand: TvBrand.androidTv,
  capabilities: const TvCapabilities().capabilitiesFor(TvBrand.androidTv),
  host: host,
);

/// Elapses one full fast phase (3 attempts -- the first immediate, the other
/// two one tick apart) plus escalation, landing exactly at the moment a wait
/// phase begins -- the point every growth/cap test below needs to inspect
/// [ReconnectionRetryState.waitSecondsRemaining] at.
void _driveOneLapToWait(
  FakeAsync async, {
  Duration interval = const Duration(seconds: 5),
}) {
  async.elapse(interval * 2);
  async.flushMicrotasks();
}

void main() {
  group('ReconnectionRetryController', () {
    test('fast phase fires an immediate connect on start', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final controller = _buildController(commandService: commandService);
        addTearDown(controller.dispose);

        controller.start(_device(id: 'androidtv-abc', host: '10.0.0.5'));

        expect(commandService.connectCallCount, 1);
        expect(
          controller.stateNotifier.value?.phase,
          ReconnectionPhase.fastRetry,
        );
      });
    });

    test('fires an immediate connect on start, then one connect per '
        'subsequent fast-phase tick, then escalates and fires an extra '
        'connect before entering the wait phase', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final discovery = _ScriptedDiscoveryService(const []);
        final controller = _buildController(
          commandService: commandService,
          discoveryService: discovery,
        );
        addTearDown(controller.dispose);
        final device = _device(id: 'androidtv-abc', host: '10.0.0.5');

        controller.start(device);
        expect(commandService.connectCallCount, 1);

        async.elapse(const Duration(seconds: 5));
        expect(commandService.connectCallCount, 2);

        // Second tick fires the last (third) fast attempt, then triggers
        // escalation (discovery + reconcile + one more connect) before
        // waiting.
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(discovery.callCount, 1);
        expect(commandService.connectCallCount, 4);
        expect(
          controller.stateNotifier.value?.phase,
          ReconnectionPhase.waiting,
        );
        expect(controller.stateNotifier.value?.waitSecondsRemaining, 45);
      });
    });

    test('wait phase counts down every second and loops back to the fast phase '
        'at zero', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final discovery = _ScriptedDiscoveryService(const []);
        final controller = _buildController(
          commandService: commandService,
          discoveryService: discovery,
        );
        addTearDown(controller.dispose);
        controller.start(_device(id: 'androidtv-abc', host: '10.0.0.5'));

        // The immediate-fire fix moves escalation (and wait-phase entry)
        // from t=15s to t=10s: connects at t=0 (start), t=5s, t=10s (third
        // attempt, triggers escalation).
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(controller.stateNotifier.value?.waitSecondsRemaining, 45);

        async.elapse(const Duration(seconds: 10));
        expect(controller.stateNotifier.value?.waitSecondsRemaining, 35);

        final connectCountBeforeLoop = commandService.connectCallCount;
        async.elapse(const Duration(seconds: 35));
        expect(
          controller.stateNotifier.value?.phase,
          ReconnectionPhase.fastRetry,
        );
        // The new fast phase fires an immediate connect too, same as start().
        expect(commandService.connectCallCount, connectCountBeforeLoop + 1);

        async.elapse(const Duration(seconds: 5));
        expect(commandService.connectCallCount, connectCountBeforeLoop + 2);
      });
    });

    test('retryNow cancels the wait, fires a connect immediately, and resumes '
        'the fast phase', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final discovery = _ScriptedDiscoveryService(const []);
        final controller = _buildController(
          commandService: commandService,
          discoveryService: discovery,
        );
        addTearDown(controller.dispose);
        controller.start(_device(id: 'androidtv-abc', host: '10.0.0.5'));

        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();
        expect(
          controller.stateNotifier.value?.phase,
          ReconnectionPhase.waiting,
        );
        final connectCountWhileWaiting = commandService.connectCallCount;

        controller.retryNow();

        // Fires immediately -- no elapsed time required.
        expect(commandService.connectCallCount, connectCountWhileWaiting + 1);
        expect(
          controller.stateNotifier.value?.phase,
          ReconnectionPhase.fastRetry,
        );

        // Resumes the fast phase from here: the next attempt is a normal
        // 5s tick away, not immediate again, and not skipped either.
        async.elapse(const Duration(seconds: 4));
        expect(commandService.connectCallCount, connectCountWhileWaiting + 1);
        async.elapse(const Duration(seconds: 1));
        expect(commandService.connectCallCount, connectCountWhileWaiting + 2);
      });
    });

    test('retryNow is a no-op while idle', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final controller = _buildController(commandService: commandService);
        addTearDown(controller.dispose);

        controller.retryNow();

        expect(commandService.connectCallCount, 0);
        expect(controller.stateNotifier.value, isNull);
      });
    });

    test('stop cancels the cycle and returns to idle', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final controller = _buildController(commandService: commandService);
        addTearDown(controller.dispose);
        controller.start(_device(id: 'androidtv-abc', host: '10.0.0.5'));
        expect(commandService.connectCallCount, 1);

        controller.stop();
        expect(controller.stateNotifier.value, isNull);

        async.elapse(const Duration(seconds: 30));
        expect(commandService.connectCallCount, 1);
      });
    });

    test('skips (does not count) a fast-phase tick while canAttemptNow is '
        'false, and resumes cleanly once true again', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        var canAttempt = false;
        final controller = _buildController(
          commandService: commandService,
          canAttemptNow: () => canAttempt,
        );
        addTearDown(controller.dispose);
        controller.start(_device(id: 'androidtv-abc', host: '10.0.0.5'));

        // The immediate fire on start() is itself gated by canAttemptNow.
        expect(commandService.connectCallCount, 0);

        async.elapse(const Duration(seconds: 5));
        expect(commandService.connectCallCount, 0);

        canAttempt = true;
        async.elapse(const Duration(seconds: 5));
        expect(commandService.connectCallCount, 1);
      });
    });

    test('escalation reconciles a moved device: persists the new host, reports '
        'the update, and dials the new host for its own next attempt', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final repository = InMemoryDeviceRepository();
        final identityRegistry = DeviceIdentityRegistry();
        final savedDevice = _device(
          id: 'androidtv-cert-abc123',
          host: '10.0.0.5',
        );
        final movedDiscoveredDevice = savedDevice.copyWith(host: '10.0.0.9');
        unawaited(repository.saveDevice(savedDevice));
        final discovery = _ScriptedDiscoveryService([movedDiscoveredDevice]);
        final updatedDevices = <TvDevice>[];

        final controller = ReconnectionRetryController(
          commandService: commandService,
          discoveryService: discovery,
          deviceRepository: repository,
          identityRegistry: identityRegistry,
          layoutRepository: null,
          canAttemptNow: () => true,
          onDeviceUpdated: updatedDevices.add,
        );
        addTearDown(controller.dispose);

        controller.start(savedDevice);
        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();

        expect(updatedDevices, hasLength(1));
        expect(updatedDevices.single.resolvedHost, '10.0.0.9');
        expect(
          commandService.connectedDevices.last.resolvedHost,
          '10.0.0.9',
          reason:
              'the connect fired right after escalation must use the '
              'freshly reconciled host, not the stale one the cycle '
              'started with',
        );

        List<TvDevice>? persisted;
        repository.getSavedDevices().then((devices) => persisted = devices);
        async.flushMicrotasks();
        expect(persisted, isNotNull);
        expect(persisted!.single.resolvedHost, '10.0.0.9');
      });
    });

    test('a failed escalation (discovery throws) still falls through to the '
        'wait phase instead of stalling the cycle', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final discovery = _ScriptedDiscoveryService(const [])
          ..throwOnDiscover = Exception('scan failed');
        final controller = _buildController(
          commandService: commandService,
          discoveryService: discovery,
        );
        addTearDown(controller.dispose);
        controller.start(_device(id: 'androidtv-abc', host: '10.0.0.5'));

        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();

        expect(
          controller.stateNotifier.value?.phase,
          ReconnectionPhase.waiting,
        );
        // Three fast attempts, plus escalation's own connect: that fire is
        // unconditional on the outcome of discovery/reconcile (a plain
        // retry to the last-known host is still worth trying even when the
        // refresh attempt itself failed), so discovery throwing does not
        // suppress it.
        expect(commandService.connectCallCount, 4);
      });
    });

    test(
      'wait duration doubles each successive failed lap, capped at waitCap',
      () {
        fakeAsync((async) {
          final commandService = _RecordingCommandService();
          final controller = _buildController(commandService: commandService);
          addTearDown(controller.dispose);
          controller.start(_device(id: 'androidtv-abc', host: '10.0.0.5'));

          _driveOneLapToWait(async); // lap 1
          expect(controller.stateNotifier.value?.waitSecondsRemaining, 45);

          async.elapse(const Duration(seconds: 45));
          _driveOneLapToWait(async); // lap 2
          expect(controller.stateNotifier.value?.waitSecondsRemaining, 90);

          async.elapse(const Duration(seconds: 90));
          _driveOneLapToWait(async); // lap 3
          expect(controller.stateNotifier.value?.waitSecondsRemaining, 180);

          async.elapse(const Duration(seconds: 180));
          _driveOneLapToWait(async); // lap 4: 360 would exceed the 5m cap
          expect(controller.stateNotifier.value?.waitSecondsRemaining, 300);

          async.elapse(const Duration(seconds: 300));
          _driveOneLapToWait(
            async,
          ); // lap 5: stays capped, does not grow further
          expect(controller.stateNotifier.value?.waitSecondsRemaining, 300);
        });
      },
    );

    test('retryNow resets wait growth back to the base duration for the next '
        'lap', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final controller = _buildController(commandService: commandService);
        addTearDown(controller.dispose);
        controller.start(_device(id: 'androidtv-abc', host: '10.0.0.5'));

        _driveOneLapToWait(async); // lap 1: wait == 45s
        async.elapse(const Duration(seconds: 45));
        _driveOneLapToWait(async); // lap 2: wait == 90s (grown)
        expect(controller.stateNotifier.value?.waitSecondsRemaining, 90);

        controller.retryNow();
        // retryNow's immediate fire already counts as fast attempt #1, so
        // only 2 more ticks (not 3) are needed to reach the escalation.
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(
          controller.stateNotifier.value?.waitSecondsRemaining,
          45,
          reason:
              'a manual retry should not inherit growth from automatic '
              'failures earlier in the same streak',
        );
      });
    });

    test('a fresh start() after stop() resets wait growth back to the base '
        'duration', () {
      fakeAsync((async) {
        final commandService = _RecordingCommandService();
        final controller = _buildController(commandService: commandService);
        addTearDown(controller.dispose);
        final device = _device(id: 'androidtv-abc', host: '10.0.0.5');
        controller.start(device);

        _driveOneLapToWait(async); // lap 1: wait == 45s
        async.elapse(const Duration(seconds: 45));
        _driveOneLapToWait(async); // lap 2: wait == 90s (grown)
        expect(controller.stateNotifier.value?.waitSecondsRemaining, 90);

        controller.stop();
        controller.start(device); // simulates a fresh disconnected streak
        _driveOneLapToWait(async);

        expect(controller.stateNotifier.value?.waitSecondsRemaining, 45);
      });
    });
  });
}

ReconnectionRetryController _buildController({
  required _RecordingCommandService commandService,
  DeviceDiscoveryService? discoveryService,
  bool Function()? canAttemptNow,
}) {
  return ReconnectionRetryController(
    commandService: commandService,
    discoveryService: discoveryService ?? _ScriptedDiscoveryService(const []),
    deviceRepository: InMemoryDeviceRepository(),
    identityRegistry: null,
    layoutRepository: null,
    canAttemptNow: canAttemptNow ?? (() => true),
    onDeviceUpdated: (_) {},
  );
}

/// Records every device passed to [connect]; every other member of
/// [RemoteCommandService] is unused by [ReconnectionRetryController] and
/// throws if exercised, so an accidental new dependency on this fake fails
/// loudly instead of silently returning a meaningless default.
class _RecordingCommandService implements RemoteCommandService {
  final List<TvDevice> connectedDevices = [];
  int get connectCallCount => connectedDevices.length;

  @override
  Future<void> connect({required TvDevice device}) async {
    connectedDevices.add(device);
  }

  @override
  Future<CommandDispatchResult> preparePairing({required TvDevice device}) =>
      throw UnimplementedError();

  @override
  Future<void> unpairDevice({required TvDevice device}) =>
      throw UnimplementedError();

  @override
  Future<void> cancelPairing({required TvDevice device}) =>
      throw UnimplementedError();

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) => throw UnimplementedError();

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) => throw UnimplementedError();

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) => throw UnimplementedError();

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) =>
      throw UnimplementedError();

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) =>
      throw UnimplementedError();

  @override
  Future<bool> checkRemoteTextInputReady({required TvDevice device}) =>
      throw UnimplementedError();

  @override
  Stream<ConnectionState> watchConnectionState({required TvDevice device}) =>
      throw UnimplementedError();

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) =>
      throw UnimplementedError();

  @override
  Future<void> pauseMonitoring({required TvDevice device}) =>
      throw UnimplementedError();

  @override
  Future<void> resumeMonitoring({required TvDevice device}) =>
      throw UnimplementedError();
}

/// Discovery double used via [PairingPageData.discoverDevices], which sorts
/// the result -- the sort is irrelevant to these tests since each scenario
/// only ever seeds zero or one discovered device.
class _ScriptedDiscoveryService implements DeviceDiscoveryService {
  _ScriptedDiscoveryService(this._devices);

  final List<TvDevice> _devices;
  Object? throwOnDiscover;
  int callCount = 0;

  @override
  Future<List<TvDevice>> discoverDevices() async {
    callCount++;
    final error = throwOnDiscover;
    if (error != null) {
      throw error;
    }
    return _devices;
  }
}
