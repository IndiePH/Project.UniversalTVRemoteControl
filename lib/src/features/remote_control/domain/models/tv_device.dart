import 'package:one_remote/src/features/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand_capabilities.dart';

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'brand': brand.name,
    'capabilities': capabilities.map((c) => c.name).toList(),
  };

  static TvDevice? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String;
      final displayName = json['displayName'] as String;
      final brand = TvBrand.values.firstWhere((b) => b.name == json['brand']);
      // Capabilities are derived from brand defaults, not persisted values.
      // Per-device capability detection (model/firmware probing at pairing time)
      // is a planned future improvement — see goal-app-refactor-ui.md Branch 5.
      final capabilities = brand.defaultCapabilities;
      return TvDevice(id: id, displayName: displayName, brand: brand, capabilities: capabilities);
    } catch (_) {
      return null;
    }
  }
}
