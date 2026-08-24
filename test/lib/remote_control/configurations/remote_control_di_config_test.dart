import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/configurations/remote_control_di_config.dart';
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

      sl.reset();
    },
  );
}
