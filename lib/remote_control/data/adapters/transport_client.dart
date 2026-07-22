import 'package:one_remote/remote_control/domain/models/connection_state.dart';

/// Marker interface for all transport implementations (real and fake).
abstract interface class TransportClient {
  Stream<ConnectionState> watchConnectionState(String deviceId);
}
