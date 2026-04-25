import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';

abstract interface class IDiConfig {
  void configure(GetIt sl, AppEnvironment env);
}
