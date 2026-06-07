import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Application-wide source of truth for per-device transport connection state.
///
/// UI layers (home, pairing, etc.) must read from this service instead of
/// mixing transport streams with reachability probes.
abstract interface class TvConnectionStateService {
  /// Last known state for [deviceId], or [ConnectionState.disconnected] if
  /// unknown.
  ConnectionState stateFor(String deviceId);

  /// Live transport connection state for [device]. Multiplexes a single
  /// upstream subscription per device id across all listeners.
  Stream<ConnectionState> watch(TvDevice device);
}
