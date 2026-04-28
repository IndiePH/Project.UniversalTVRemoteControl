import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/app_localized_strings.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/di_bootstrap.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/transport_log_reader_provider.dart';
import 'package:one_remote/remote_control/presentation/pages/remote_home_page.dart';
import 'package:one_remote/theme/app_theme.dart';

class OneRemoteApp extends StatelessWidget {
  const OneRemoteApp({super.key});

  static Future<void> restart() async {
    final env = GetIt.instance<AppEnvironment>();
    await GetIt.instance.reset();
    await DiBootstrap.initialize(env);
    runApp(OneRemoteApp(key: UniqueKey()));
  }

  @override
  Widget build(BuildContext context) {
    final sl = GetIt.instance;
    return ValueListenableBuilder<Locale>(
      valueListenable: sl<ValueNotifier<Locale>>(),
      builder: (_, locale, _) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        builder: (context, child) {
          AppLocalizedStrings.update(AppLocalizations.of(context)!);
          return child!;
        },
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme(),
        home: RemoteHomePage(
          commandService: sl<RemoteCommandService>(),
          deviceRepository: sl<DeviceRepository>(),
          discoveryService: sl<DeviceDiscoveryService>(),
          layoutRepository: sl<LayoutRepository>(),
          transportLogReaderProvider: sl<TransportLogReaderProvider>(),
        ),
      ),
    );
  }
}
