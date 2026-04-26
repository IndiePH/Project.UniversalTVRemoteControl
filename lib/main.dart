import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/di_bootstrap.dart';
import 'package:one_remote/app/one_remote_app.dart';
import 'package:one_remote/app/stream_unhandled_error_source.dart';

StreamUnhandledErrorSource? _errorSource() {
  final sl = GetIt.instance;
  return sl.isRegistered<StreamUnhandledErrorSource>()
      ? sl<StreamUnhandledErrorSource>()
      : null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final env = kDebugMode ? AppEnvironment.debug : AppEnvironment.production;
  await DiBootstrap.initialize(env);

  FlutterError.onError = (FlutterErrorDetails details) {
    final errorSource = _errorSource();
    if (errorSource != null) {
      errorSource.add(details.exception);
    } else if (env == AppEnvironment.debug) {
      FlutterError.presentError(details);
    }
  };

  runZonedGuarded(
    () => runApp(const OneRemoteApp()),
    (Object error, StackTrace stack) {
      final errorSource = _errorSource();
      if (errorSource != null) {
        errorSource.add(error);
      } else if (env == AppEnvironment.debug) {
        debugPrint('Unhandled error: $error\n$stack');
      }
    },
  );
}
