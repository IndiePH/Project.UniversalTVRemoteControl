import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand_capabilities.dart';

class TvDevice {
  const TvDevice({
    required this.id,
    required this.displayName,
    required this.brand,
    required this.capabilities,
    this.protocolVariant = defaultProtocolVariant,
  });

  static const String defaultProtocolVariant = 'default';

  final String id;
  final String displayName;
  final TvBrand brand;
  final Set<DeviceCapability> capabilities;
  final String protocolVariant;

  TvDevice copyWith({
    Set<DeviceCapability>? capabilities,
    String? protocolVariant,
  }) =>
      TvDevice(
        id: id,
        displayName: displayName,
        brand: brand,
        capabilities: capabilities ?? this.capabilities,
        protocolVariant: protocolVariant ?? this.protocolVariant,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'brand': brand.name,
    'capabilities': capabilities.map((c) => c.name).toList(),
    'protocolVariant': protocolVariant,
  };

  static TvDevice? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String;
      final displayName = json['displayName'] as String;
      final brand = TvBrand.values.firstWhere((b) => b.name == json['brand']);
      final protocolVariant =
          json['protocolVariant'] as String? ?? defaultProtocolVariant;
      final capabilityNames =
          (json['capabilities'] as List<dynamic>?)?.cast<String>() ?? [];
      final parsed = capabilityNames
          .map((n) {
            try {
              return DeviceCapability.values.byName(n);
            } catch (_) {
              return null;
            }
          })
          .nonNulls
          .toSet();
      final capabilities =
          parsed.isEmpty ? brand.defaultCapabilities : parsed;
      return TvDevice(
        id: id,
        displayName: displayName,
        brand: brand,
        capabilities: capabilities,
        protocolVariant: protocolVariant,
      );
    } catch (_) {
      return null;
    }
  }
}
