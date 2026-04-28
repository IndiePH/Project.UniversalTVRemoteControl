import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import '../../../fakes/fake_localized_strings.dart';

void main() {
  late FakeLocalizedStrings fake;
  late DefaultPrePairingStepsRegistry registry;

  setUp(() {
    fake = FakeLocalizedStrings();
    registry = DefaultPrePairingStepsRegistry(localizedStrings: fake);
  });

  group('DefaultPrePairingStepsRegistry.stepsFor', () {
    test('returns two LG steps for LG default variant', () {
      final steps = registry.stepsFor(TvBrand.lg, TvDevice.defaultProtocolVariant);
      expect(steps, isNotNull);
      expect(steps, [fake.pairingLgPreStep0, fake.pairingLgPreStep1]);
    });

    test('returns two Samsung steps for Samsung default variant', () {
      final steps = registry.stepsFor(TvBrand.samsung, TvDevice.defaultProtocolVariant);
      expect(steps, isNotNull);
      expect(steps, [fake.pairingSamsungPreStep0, fake.pairingSamsungPreStep1]);
    });

    test('returns null for Hisense (no pre-pairing steps defined)', () {
      expect(
        registry.stepsFor(TvBrand.hisense, TvDevice.defaultProtocolVariant),
        isNull,
      );
    });

    test('returns null for unknown variant of known brand', () {
      expect(registry.stepsFor(TvBrand.lg, 'unknown_variant'), isNull);
    });

    test('LG steps list has exactly two entries', () {
      final steps = registry.stepsFor(TvBrand.lg, TvDevice.defaultProtocolVariant)!;
      expect(steps, hasLength(2));
    });

    test('Samsung steps list has exactly two entries', () {
      final steps = registry.stepsFor(TvBrand.samsung, TvDevice.defaultProtocolVariant)!;
      expect(steps, hasLength(2));
    });
  });
}
