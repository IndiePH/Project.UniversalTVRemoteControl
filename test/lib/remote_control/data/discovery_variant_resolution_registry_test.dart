import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_protocol_variants.dart';
import 'package:one_remote/remote_control/data/discovery_variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/discovery_source.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  const registry = DefaultDiscoveryVariantResolutionRegistry();

  group('DefaultDiscoveryVariantResolutionRegistry', () {
    test('falls back to the default protocol variant when no source given', () {
      expect(
        registry.resolveFromDiscovery(brand: TvBrand.androidTv, source: null),
        TvDevice.defaultProtocolVariant,
      );
    });

    test('falls back to the default protocol variant for an unmapped brand/source pair', () {
      for (final source in DiscoverySource.values) {
        expect(
          registry.resolveFromDiscovery(brand: TvBrand.roku, source: source),
          TvDevice.defaultProtocolVariant,
        );
      }
    });

    test('resolves Sony found via SSDP to the BRAVIA IP Control variant', () {
      expect(
        registry.resolveFromDiscovery(
          brand: TvBrand.sony,
          source: DiscoverySource.ssdp,
        ),
        SonyProtocolVariants.braviaIpControl,
      );
    });

    test('falls back to the default protocol variant for Sony found via other sources', () {
      for (final source in [DiscoverySource.mdns, DiscoverySource.roku]) {
        expect(
          registry.resolveFromDiscovery(brand: TvBrand.sony, source: source),
          TvDevice.defaultProtocolVariant,
        );
      }
    });
  });
}
