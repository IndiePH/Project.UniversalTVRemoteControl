import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/configurations/remote_control_di_config.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_protocol_variants.dart';
import 'package:one_remote/remote_control/data/manual_add_variant_probe.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../fakes/fake_localized_strings.dart';

// Regression guard for A4 of goal-sony-adapter.md: fails if SonyAdapter is
// ever dropped from either adapters-list literal in remote_control_di_config.dart.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const sonyDevice = TvDevice(
    id: 'sony-di-smoke',
    displayName: 'Sony DI Smoke Test',
    brand: TvBrand.sony,
    capabilities: {
      DeviceCapability.keyCommands,
      DeviceCapability.textInput,
      DeviceCapability.powerControl,
    },
    host: '192.168.1.40',
  );

  // Regression guard for C4 of goal-sony-adapter.md: fails if SonyBraviaAdapter
  // is ever dropped from either adapters-list literal.
  const sonyBraviaDevice = TvDevice(
    id: 'sony-bravia-di-smoke',
    displayName: 'Sony BRAVIA DI Smoke Test',
    brand: TvBrand.sony,
    protocolVariant: SonyProtocolVariants.braviaIpControl,
    capabilities: {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
    },
    host: '192.168.1.41',
  );

  test(
    'DebugRemoteControlDiConfig wires a reachable adapter for TvBrand.sony',
    () async {
      final sl = GetIt.asNewInstance();
      sl.registerSingleton<LocalizedStrings>(FakeLocalizedStrings());

      const DebugRemoteControlDiConfig().configure(sl, AppEnvironment.debug);

      final reachability = sl<TvReachabilityService>();
      expect(await reachability.isReachable(sonyDevice), isTrue);

      await sl.reset();
    },
  );

  test(
    'DebugRemoteControlDiConfig wires a reachable adapter for Sony BRAVIA IP Control',
    () async {
      final sl = GetIt.asNewInstance();
      sl.registerSingleton<LocalizedStrings>(FakeLocalizedStrings());

      const DebugRemoteControlDiConfig().configure(sl, AppEnvironment.debug);

      final reachability = sl<TvReachabilityService>();
      expect(await reachability.isReachable(sonyBraviaDevice), isTrue);

      await sl.reset();
    },
  );

  test(
    'DebugRemoteControlDiConfig wires ManualAddVariantProbe with both Sony variants as candidates',
    () async {
      final sl = GetIt.asNewInstance();
      sl.registerSingleton<LocalizedStrings>(FakeLocalizedStrings());

      const DebugRemoteControlDiConfig().configure(sl, AppEnvironment.debug);

      expect(sl.isRegistered<ManualAddVariantProbe>(), isTrue);
      final probe = sl<ManualAddVariantProbe>();
      // Fake transports' probe() always succeeds, so this deterministically
      // resolves to the first entry in _variantTryOrder[TvBrand.sony] — this
      // assertion is really checking that Sony's *two* adapters both reached
      // the probe as candidates (a single-candidate brand would resolve
      // instantly with no ordering to exercise at all).
      final variant = await probe.resolve(
        brand: TvBrand.sony,
        host: '192.168.1.41',
      );
      expect(variant, SonyProtocolVariants.defaultVariant);

      await sl.reset();
    },
  );

  test(
    'RemoteControlDiConfig (release) wires a SonyAdapter into the adapters list',
    () {
      final sl = GetIt.asNewInstance();
      sl.registerSingleton<LocalizedStrings>(FakeLocalizedStrings());

      expect(
        () => const RemoteControlDiConfig().configure(
          sl,
          AppEnvironment.production,
        ),
        returnsNormally,
      );
      expect(sl.isRegistered<TvReachabilityService>(), isTrue);
      expect(sl.isRegistered<ManualAddVariantProbe>(), isTrue);

      sl.reset();
    },
  );
}
