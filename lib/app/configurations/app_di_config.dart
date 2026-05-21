import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/app/stream_unhandled_error_source.dart';
import 'package:one_remote/app/unhandled_error_source.dart';

final class DevAppDiConfig implements IDiConfig {
  const DevAppDiConfig();

  @override
  void configure(GetIt sl, AppEnvironment env) {
    final source = StreamUnhandledErrorSource();
    sl.registerSingleton<StreamUnhandledErrorSource>(source);
    sl.registerSingleton<UnhandledErrorSource>(source);
  }
}
