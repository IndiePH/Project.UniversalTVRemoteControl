import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/configurations/app_build_config.dart';
import 'package:one_remote/app/configurations/app_environment.dart';

void main() {
  test('environmentForMain follows compile-time debug flag', () {
    final expected = kDebugMode
        ? AppEnvironment.debug
        : AppEnvironment.production;
    expect(AppBuildConfig.environmentForMain(), expected);
  });

  test('development flavor hook stays reserved', () {
    expect(AppBuildConfig.developmentFlavorReserved, isFalse);
  });
}
