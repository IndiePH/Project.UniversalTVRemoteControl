import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_protocol_variants.dart';
import 'package:one_remote/remote_control/data/manual_add_variant_probe.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  test(
    'resolves with zero I/O when a brand has exactly one candidate adapter',
    () async {
      final lg = _FakeAdapter(brand: TvBrand.lg);
      final probe = DefaultManualAddVariantProbe(adapters: [lg]);

      final variant = await probe.resolve(brand: TvBrand.lg, host: '10.0.0.5');

      expect(variant, TvDevice.defaultProtocolVariant);
      expect(lg.probedDevices, isEmpty);
    },
  );

  test(
    'falls back to the default variant with zero I/O when the brand has no adapter at all',
    () async {
      final probe = DefaultManualAddVariantProbe(adapters: const []);

      final variant = await probe.resolve(
        brand: TvBrand.sony,
        host: '10.0.0.5',
      );

      expect(variant, TvDevice.defaultProtocolVariant);
    },
  );

  test(
    'probes in try-order and returns the first candidate that responds',
    () async {
      final googleTvPath = _FakeAdapter(
        brand: TvBrand.sony,
        protocolVariant: SonyProtocolVariants.defaultVariant,
      );
      final braviaPath = _FakeAdapter(
        brand: TvBrand.sony,
        protocolVariant: SonyProtocolVariants.braviaIpControl,
      );
      final probe = DefaultManualAddVariantProbe(
        adapters: [braviaPath, googleTvPath],
      );

      final variant = await probe.resolve(
        brand: TvBrand.sony,
        host: '10.0.0.7',
      );

      expect(variant, SonyProtocolVariants.defaultVariant);
      expect(googleTvPath.probedDevices, hasLength(1));
      expect(googleTvPath.probedDevices.single.host, '10.0.0.7');
      expect(
        googleTvPath.probedDevices.single.protocolVariant,
        SonyProtocolVariants.defaultVariant,
      );
      // Bravia is second in try-order — never reached once the first
      // candidate answers.
      expect(braviaPath.probedDevices, isEmpty);
    },
  );

  test(
    'falls through to the next candidate when the first does not respond',
    () async {
      final googleTvPath = _FakeAdapter(
        brand: TvBrand.sony,
        protocolVariant: SonyProtocolVariants.defaultVariant,
        probeSucceeds: false,
      );
      final braviaPath = _FakeAdapter(
        brand: TvBrand.sony,
        protocolVariant: SonyProtocolVariants.braviaIpControl,
      );
      final probe = DefaultManualAddVariantProbe(
        adapters: [braviaPath, googleTvPath],
      );

      final variant = await probe.resolve(
        brand: TvBrand.sony,
        host: '10.0.0.7',
      );

      expect(variant, SonyProtocolVariants.braviaIpControl);
      expect(googleTvPath.probedDevices, hasLength(1));
      expect(braviaPath.probedDevices, hasLength(1));
    },
  );

  test(
    'falls back to the default variant when no candidate responds',
    () async {
      final googleTvPath = _FakeAdapter(
        brand: TvBrand.sony,
        protocolVariant: SonyProtocolVariants.defaultVariant,
        probeSucceeds: false,
      );
      final braviaPath = _FakeAdapter(
        brand: TvBrand.sony,
        protocolVariant: SonyProtocolVariants.braviaIpControl,
        probeSucceeds: false,
      );
      final probe = DefaultManualAddVariantProbe(
        adapters: [googleTvPath, braviaPath],
      );

      final variant = await probe.resolve(
        brand: TvBrand.sony,
        host: '10.0.0.7',
      );

      expect(variant, TvDevice.defaultProtocolVariant);
    },
  );

  test('does not probe candidates of a different brand', () async {
    final lg = _FakeAdapter(brand: TvBrand.lg);
    final samsung = _FakeAdapter(brand: TvBrand.samsung);
    final probe = DefaultManualAddVariantProbe(adapters: [lg, samsung]);

    await probe.resolve(brand: TvBrand.samsung, host: '10.0.0.9');

    expect(lg.probedDevices, isEmpty);
  });
}

class _FakeAdapter extends TvBrandAdapter {
  _FakeAdapter({
    required this.brand,
    this.protocolVariant = TvDevice.defaultProtocolVariant,
    this.probeSucceeds = true,
  });

  @override
  final TvBrand brand;

  @override
  final String protocolVariant;

  final bool probeSucceeds;
  final List<TvDevice> probedDevices = [];

  @override
  bool get supportsTextInput => false;

  @override
  Set<RemoteCommand> get supportedCommands => const {};

  @override
  Future<void> probeConnection({required TvDevice device}) async {
    probedDevices.add(device);
    if (!probeSucceeds) {
      throw Exception('unreachable');
    }
  }

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {}

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {}
}
