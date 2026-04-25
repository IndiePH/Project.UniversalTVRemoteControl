import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/remote_control/configurations/remote_control_di_config.dart';

final class DiBootstrap {
  DiBootstrap._();

  static final List<IDiConfig> _configs = [
    const RemoteControlDiConfig(),
  ];

  static void initialize(AppEnvironment env) {
    final sl = GetIt.instance;
    sl.registerSingleton<AppEnvironment>(env);
    for (final config in _configs) {
      config.configure(sl, env);
    }
  }
}
