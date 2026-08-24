import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

void main() {
  const registry = DefaultVariantResolutionRegistry();

  group('DefaultVariantResolutionRegistry', () {
    test('returns default when info is null', () {
      expect(
        registry.resolve(brand: TvBrand.samsung, info: null),
        TvDevice.defaultProtocolVariant,
      );
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

    test('falls through brand catch-all to default for non-matching info', () {
      expect(
        registry.resolve(
          brand: TvBrand.samsung,
          info: const TvDeviceInfo(modelIdentifier: 'UN55-Frame'),
        ),
        TvDevice.defaultProtocolVariant,
      );
    });

    test('resolves Sony to the default protocol variant', () {
      expect(
        registry.resolve(
          brand: TvBrand.sony,
          info: const TvDeviceInfo(modelIdentifier: 'BRAVIA XR'),
        ),
        TvDevice.defaultProtocolVariant,
      );
    });
  });
}
