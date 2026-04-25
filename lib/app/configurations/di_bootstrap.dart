import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_di_config.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/remote_control/configurations/remote_control_di_config.dart';

final class DiBootstrap {
  DiBootstrap._();

  static List<IDiConfig> _configsFor(AppEnvironment env) => switch (env) {
    AppEnvironment.production => [
      const RemoteControlDiConfig(),
    ],
    AppEnvironment.development => [
      const RemoteControlDiConfig(),
      const DevAppDiConfig(),
    ],
    AppEnvironment.debug => [
      const DebugRemoteControlDiConfig(),
      const DevAppDiConfig(),
    ],
  };

  static void initialize(AppEnvironment env) {
    final sl = GetIt.instance;
    sl.registerSingleton<AppEnvironment>(env);
    for (final config in _configsFor(env)) {
      config.configure(sl, env);
    }
  }
}
