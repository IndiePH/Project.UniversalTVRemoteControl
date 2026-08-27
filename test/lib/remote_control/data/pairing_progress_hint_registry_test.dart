import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import '../../../fakes/fake_localized_strings.dart';

void main() {
  late FakeLocalizedStrings fake;
  late DefaultPairingProgressHintRegistry registry;

  setUp(() {
    fake = FakeLocalizedStrings();
    registry = DefaultPairingProgressHintRegistry(localizedStrings: fake);
  });

  group('DefaultPairingProgressHintRegistry.hintFor', () {
    test('returns LG hint for LG default variant', () {
      expect(
        registry.hintFor(TvBrand.lg, TvDevice.defaultProtocolVariant),
        fake.pairingLgProgressHint,
      );
    });

    test('returns Samsung hint for Samsung default variant', () {
      expect(
        registry.hintFor(TvBrand.samsung, TvDevice.defaultProtocolVariant),
        fake.pairingSamsungProgressHint,
      );
    });

    test('returns Hisense hint for Hisense default variant', () {
      expect(
        registry.hintFor(TvBrand.hisense, TvDevice.defaultProtocolVariant),
        fake.pairingHisenseProgressHint,
      );
    });

    test('returns Sony hint for Sony default variant', () {
      expect(
        registry.hintFor(TvBrand.sony, TvDevice.defaultProtocolVariant),
        fake.pairingSonyProgressHint,
      );
    });

    test('returns null for unknown variant of known brand', () {
      expect(registry.hintFor(TvBrand.lg, 'unknown_variant'), isNull);
    });

    test('returns null for unknown brand', () {
      expect(registry.hintFor(TvBrand.hisense, 'custom_variant'), isNull);
    });
  });
}
