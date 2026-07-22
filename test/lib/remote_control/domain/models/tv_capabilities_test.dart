import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  const caps = TvCapabilities();

  group('TvCapabilities.capabilitiesFor', () {
    test('returns brand default when no variant supplied', () {
      final lg = caps.capabilitiesFor(TvBrand.lg);
      final lgDefault = caps.capabilitiesFor(
        TvBrand.lg,
        TvDevice.defaultProtocolVariant,
      );
      expect(lg, equals(lgDefault));
    });

    test('returns brand default when variant is unknown', () {
      final withUnknown = caps.capabilitiesFor(
        TvBrand.samsung,
        'unknown_variant_xyz',
      );
      final brandDefault = caps.capabilitiesFor(TvBrand.samsung);
      expect(withUnknown, equals(brandDefault));
    });

    test('returns non-empty set for every registered brand', () {
      for (final brand in TvBrand.values) {
        expect(
          caps.capabilitiesFor(brand),
          isNotEmpty,
          reason: '${brand.name} must have a non-empty capability set',
        );
      }
    });
  });
}
