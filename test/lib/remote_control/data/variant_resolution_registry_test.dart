import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

void main() {
  const registry = DefaultVariantResolutionRegistry();

  group('DefaultVariantResolutionRegistry', () {
    test('returns null when info is null', () {
      expect(registry.resolve(brand: TvBrand.samsung, info: null), isNull);
    });

    test('resolves TCL legacy Wi-Fi from transport model marker', () {
      expect(
        registry.resolve(
          brand: TvBrand.tcl,
          info: const TvDeviceInfo(
            modelIdentifier: TclProtocolVariants.legacyWifiModelMarker,
          ),
        ),
        TclProtocolVariants.legacyWifi,
      );
    });

    test('falls through TCL catch-all to legacy Wi-Fi for empty info', () {
      expect(
        registry.resolve(brand: TvBrand.tcl, info: const TvDeviceInfo()),
        TclProtocolVariants.legacyWifi,
      );
    });

    test('returns null for a brand with no info-based dialect rules', () {
      expect(
        registry.resolve(
          brand: TvBrand.samsung,
          info: const TvDeviceInfo(modelIdentifier: 'UN55-Frame'),
        ),
        isNull,
      );
    });

    test('returns null for Sony (no info-based dialect rules yet)', () {
      expect(
        registry.resolve(
          brand: TvBrand.sony,
          info: const TvDeviceInfo(modelIdentifier: 'BRAVIA XR'),
        ),
        isNull,
      );
    });
  });
}
