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

  // No brand currently needs a discovery-time override — Sony's
  // SSDP-discoverable BRAVIA path has no scanner fingerprint or adapter yet
  // (Sub-goal C, not started). Add entries here once both exist, e.g.
  // (TvBrand.sony, DiscoverySource.ssdp): SonyProtocolVariants.braviaIpControl.
  static const Map<(TvBrand, DiscoverySource?), String> _discoveryEntries = {};

  @override
  String resolveFromDiscovery({
    required TvBrand brand,
    required DiscoverySource? source,
  }) => _discoveryEntries[(brand, source)] ?? TvDevice.defaultProtocolVariant;
}
