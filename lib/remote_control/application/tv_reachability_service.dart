import 'package:one_remote/remote_control/domain/models/tv_device.dart';

abstract interface class TvReachabilityService {
  /// Returns true if [device] is reachable on the local network, false otherwise.
  Future<bool> isReachable(TvDevice device);
}
