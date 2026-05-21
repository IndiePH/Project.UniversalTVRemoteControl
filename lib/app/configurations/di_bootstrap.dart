import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/app_localized_strings.dart';
import 'package:one_remote/app/configurations/app_di_config.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/app_monetization_di_config.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/app/theme/app_theme_controller.dart';
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
      AppEnvironment.production => [
        const RemoteControlDiConfig(),
        const AppMonetizationDiConfig(),
      ],
      AppEnvironment.development || AppEnvironment.debug => [
        useFake
            ? const DebugRemoteControlDiConfig()
            : const RemoteControlDiConfig(),
        const DevAppDiConfig(),
        const AppMonetizationDiConfig(),
      ],
    };
  }

  static Future<void> initialize(AppEnvironment env) async {
    final sl = GetIt.instance;
    sl.registerSingleton<AppEnvironment>(env);
    sl.registerSingleton<ValueNotifier<Locale>>(
      ValueNotifier(PlatformDispatcher.instance.locale),
    );
    sl.registerSingleton<LocalizedStrings>(AppLocalizedStrings());
    sl.registerSingleton<AppThemeController>(await AppThemeController.load());
    for (final config in await _configsFor(env)) {
      config.configure(sl, env);
    }
  }
}
