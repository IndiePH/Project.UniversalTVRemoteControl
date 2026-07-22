import 'dart:async';

import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/tv_connection_state_service.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Multiplexes [RemoteCommandService.watchConnectionState] per device id so
/// every UI surface shares one upstream transport subscription and snapshot.
final class MultiplexedTvConnectionStateService
    implements TvConnectionStateService {
  MultiplexedTvConnectionStateService({required this._commandService});

  final RemoteCommandService _commandService;
  final Map<String, ConnectionState> _lastStates = <String, ConnectionState>{};
  final Map<String, StreamController<ConnectionState>> _controllers =
      <String, StreamController<ConnectionState>>{};
  final Map<String, StreamSubscription<ConnectionState>?> _upstreamSubs =
      <String, StreamSubscription<ConnectionState>?>{};
  final Map<String, TvDevice> _watchedDevices = <String, TvDevice>{};

  @override
  ConnectionState stateFor(String deviceId) =>
      _lastStates[deviceId] ?? ConnectionState.disconnected;

  @override
  Stream<ConnectionState> watch(TvDevice device) {
    _watchedDevices[device.id] = device;
    _ensureUpstream(device);
    return _controllerFor(device.id).stream;
  }

  void _ensureUpstream(TvDevice device) {
    if (_upstreamSubs.containsKey(device.id)) {
      return;
    }
    _upstreamSubs[device.id] = _commandService
        .watchConnectionState(device: device)
        .listen(
          (state) => _emit(device.id, state),
          onError: (_) => _emit(device.id, ConnectionState.error),
        );
  }

  void _emit(String deviceId, ConnectionState state) {
    if (_lastStates[deviceId] == state) {
      return;
    }
    _lastStates[deviceId] = state;
    final controller = _controllers[deviceId];
    if (controller != null && !controller.isClosed) {
      controller.add(state);
    }
  }

  StreamController<ConnectionState> _controllerFor(String deviceId) {
    return _controllers.putIfAbsent(deviceId, () {
      return StreamController<ConnectionState>.broadcast(
        onListen: () {
          _controllers[deviceId]?.add(
            _lastStates[deviceId] ?? ConnectionState.disconnected,
          );
        },
        onCancel: () {
          final controller = _controllers[deviceId];
          if (controller != null && !controller.hasListener) {
            _tearDown(deviceId);
          }
        },
      );
    });
  }

  void _tearDown(String deviceId) {
    _upstreamSubs.remove(deviceId)?.cancel();
    _watchedDevices.remove(deviceId);
    final controller = _controllers.remove(deviceId);
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }
}
