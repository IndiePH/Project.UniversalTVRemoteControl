import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/device_capability.dart';

class TvDevice {
  const TvDevice({
    required this.id,
    required this.displayName,
    required this.brand,
    required this.capabilities,
  });

  final String id;
  final String displayName;
  final TvBrand brand;
  final Set<DeviceCapability> capabilities;
}
