import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/di_bootstrap.dart';
import 'package:one_remote/app/one_remote_app.dart';
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

  runApp(const OneRemoteApp());
}
