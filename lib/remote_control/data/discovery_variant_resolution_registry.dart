import 'package:one_remote/remote_control/data/adapters/sony/sony_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/discovery_source.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Resolves a device's structural protocol variant (which transport/adapter)
/// from how it was discovered, before any adapter has been selected.
///
/// See also variant_resolution_registry.dart's VariantResolutionRegistry,
/// which resolves the behavioral variant (which dialect within an
/// already-fixed transport) from a live adapter probe, post-first-contact.
/// Never both live at once: discovery source is only known before first
/// contact, TvDeviceInfo only after.
abstract interface class DiscoveryVariantResolutionRegistry {
  String resolveFromDiscovery({
    required TvBrand brand,
    required DiscoverySource? source,
  });
}

class DefaultDiscoveryVariantResolutionRegistry
    implements DiscoveryVariantResolutionRegistry {
  const DefaultDiscoveryVariantResolutionRegistry();

  static const Map<(TvBrand, DiscoverySource?), String> _discoveryEntries = {
    (TvBrand.sony, DiscoverySource.ssdp): SonyProtocolVariants.braviaIpControl,
  };

  @override
  String resolveFromDiscovery({
    required TvBrand brand,
    required DiscoverySource? source,
  }) => _discoveryEntries[(brand, source)] ?? TvDevice.defaultProtocolVariant;
}
