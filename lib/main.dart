import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/di_bootstrap.dart';
import 'package:one_remote/app/one_remote_app.dart';
import 'package:one_remote/app/stream_unhandled_error_source.dart';
import 'package:one_remote/app/transport_debug_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  const compileUseFakeTransports = bool.fromEnvironment(
    'USE_FAKE_TRANSPORTS',
    defaultValue: false,
  );
  final stored = await TransportDebugSettings.readUseFakeTransportsOverride();
  final env = (stored ?? compileUseFakeTransports)
      ? AppEnvironment.debug
      : AppEnvironment.production;
  DiBootstrap.initialize(env);

  final sl = GetIt.instance;
  final errorSource = sl.isRegistered<StreamUnhandledErrorSource>()
      ? sl<StreamUnhandledErrorSource>()
      : null;

  FlutterError.onError = (FlutterErrorDetails details) {
    if (errorSource != null) {
      errorSource.add(details.exception);
    } else if (env == AppEnvironment.debug) {
      FlutterError.presentError(details);
    }
  };

  runZonedGuarded(
    () => runApp(const OneRemoteApp()),
    (Object error, StackTrace stack) {
      if (errorSource != null) {
        errorSource.add(error);
      } else if (env == AppEnvironment.debug) {
        debugPrint('Unhandled error: $error\n$stack');
      }
    },
  );
}
