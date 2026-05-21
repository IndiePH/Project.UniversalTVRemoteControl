import 'package:one_remote/remote_control/domain/models/tv_device.dart';

abstract class DeviceDiscoveryService {
  Future<List<TvDevice>> discoverDevices();
}
