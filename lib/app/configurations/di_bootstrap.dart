import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_di_config.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/app/transport_debug_settings.dart';
import 'package:one_remote/remote_control/configurations/remote_control_di_config.dart';

final class DiBootstrap {
  DiBootstrap._();

  static const bool _compileUseFakeTransports =
      bool.fromEnvironment('USE_FAKE_TRANSPORTS');

  static Future<List<IDiConfig>> _configsFor(AppEnvironment env) async {
    final stored = await TransportDebugSettings.readUseFakeTransportsOverride();
    final useFake = stored ?? _compileUseFakeTransports;
    return switch (env) {
      AppEnvironment.production => [const RemoteControlDiConfig()],
      AppEnvironment.development || AppEnvironment.debug => [
        useFake
            ? const DebugRemoteControlDiConfig()
            : const RemoteControlDiConfig(),
        const DevAppDiConfig(),
      ],
    };
  }

  static Future<void> initialize(AppEnvironment env) async {
    final sl = GetIt.instance;
    sl.registerSingleton<AppEnvironment>(env);
    for (final config in await _configsFor(env)) {
      config.configure(sl, env);
    }
  }
}
