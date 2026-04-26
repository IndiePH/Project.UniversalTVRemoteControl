import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract interface class TvModelCapabilityRegistry {
  Set<DeviceCapability> resolve({
    required TvBrand brand,
    required TvDeviceInfo? info,
  });
}

class _CapabilityEntry {
  const _CapabilityEntry({
    required this.brand,
    required this.matches,
    required this.capabilities,
  });

  final TvBrand brand;
  final bool Function(TvDeviceInfo info) matches;
  final Set<DeviceCapability> capabilities;
}

class DefaultTvModelCapabilityRegistry implements TvModelCapabilityRegistry {
  const DefaultTvModelCapabilityRegistry();

  static final _entries = <_CapabilityEntry>[
    _CapabilityEntry(
      brand: TvBrand.samsung,
      matches: (_) => true,
      capabilities: TvBrand.samsung.defaultCapabilities,
    ),
    _CapabilityEntry(
      brand: TvBrand.lg,
      matches: (_) => true,
      capabilities: TvBrand.lg.defaultCapabilities,
    ),
    _CapabilityEntry(
      brand: TvBrand.hisense,
      matches: (_) => true,
      capabilities: TvBrand.hisense.defaultCapabilities,
    ),
  ];

  @override
  Set<DeviceCapability> resolve({
    required TvBrand brand,
    required TvDeviceInfo? info,
  }) {
    if (info == null) return brand.defaultCapabilities;
    for (final entry in _entries) {
      if (entry.brand == brand && entry.matches(info)) return entry.capabilities;
    }
    return brand.defaultCapabilities;
  }
}
