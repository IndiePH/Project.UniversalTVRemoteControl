import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_device.dart';

abstract class DeviceDiscoveryService {
  Future<List<TvDevice>> discoverDevices();
}
