import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand_capabilities.dart';

abstract interface class TvModelCapabilityRegistry {
  Set<DeviceCapability> resolve({
    required TvBrand brand,
    required String? modelIdentifier,
  });
}

class DefaultTvModelCapabilityRegistry implements TvModelCapabilityRegistry {
  const DefaultTvModelCapabilityRegistry();

  @override
  Set<DeviceCapability> resolve({
    required TvBrand brand,
    required String? modelIdentifier,
  }) =>
      brand.defaultCapabilities;
}
