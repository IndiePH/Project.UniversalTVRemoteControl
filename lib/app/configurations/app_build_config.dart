import 'package:flutter/foundation.dart';

import 'package:one_remote/app/configurations/app_environment.dart';

/// Compile-time build profile (Flutter `kDebugMode` / `kReleaseMode`), not Gradle/Xcode product flavors.
enum AppBuildProfile {
  /// `flutter run` / debug APK — maps to [AppEnvironment.debug] in [environmentForMain].
  debug,

  /// `flutter run --profile` — reserved; still uses production DI until a profile hook exists.
  profile,

  /// `flutter run --release` / store builds — maps to [AppEnvironment.production].
  release,
}

/// Central mapping from Flutter build mode to app environment and future flavor hooks.
///
/// Android uses standard `debug` / `release` buildTypes only (no productFlavors yet).
/// Runtime toggles (fake transports, etc.) use `--dart-define` — see README.
abstract final class AppBuildConfig {
  /// Reserved for a future `development` Gradle flavor or `--dart-define=APP_ENV=development`.
  static const bool developmentFlavorReserved = false;

  static AppBuildProfile get profile => switch ((kDebugMode, kProfileMode)) {
    (true, _) => AppBuildProfile.debug,
    (false, true) => AppBuildProfile.profile,
    (false, false) => AppBuildProfile.release,
  };

  /// Environment wired at startup ([main]); keep in sync with README build-profile table.
  static AppEnvironment environmentForMain() => switch (profile) {
    AppBuildProfile.debug => AppEnvironment.debug,
    AppBuildProfile.profile ||
    AppBuildProfile.release => AppEnvironment.production,
  };
}
