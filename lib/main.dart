import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_remote/src/app/one_remote_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const OneRemoteApp());
}
