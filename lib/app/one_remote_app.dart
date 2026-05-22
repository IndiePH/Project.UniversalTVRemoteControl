import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/app_localized_strings.dart';
import 'package:one_remote/app/ads/interstitial_ad_controller.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/di_bootstrap.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/application/application.dart';
import 'package:one_remote/remote_control/presentation/presentation.dart';
import 'package:one_remote/app/theme/app_theme_controller.dart';
import 'package:one_remote/app/theme/app_theme_preference.dart';
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
    final themeController = sl<AppThemeController>();
    return ValueListenableBuilder<Locale>(
      valueListenable: sl<ValueNotifier<Locale>>(),
      builder: (context, locale, child) =>
          ValueListenableBuilder<AppThemePreference>(
            valueListenable: themeController.preferenceNotifier,
            builder: (context, themePreference, child) => MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)!.appTitle,
              builder: (context, child) {
                AppLocalizedStrings.update(AppLocalizations.of(context)!);
                return child!;
              },
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(),
              darkTheme: AppTheme.darkTheme(),
              themeMode: themePreference.themeMode,
              home: RemoteHomePage(
                appEnvironment: sl<AppEnvironment>(),
                interstitialAdController: sl<InterstitialAdController>(),
                commandService: sl<RemoteCommandService>(),
                deviceRepository: sl<DeviceRepository>(),
                discoveryService: sl<DeviceDiscoveryService>(),
                layoutRepository: sl<LayoutRepository>(),
                proEntitlementService: sl<ProEntitlementService>(),
                transportLogReaderProvider: sl<TransportLogReaderProvider>(),
              ),
            ),
          ),
    );
  }
}
