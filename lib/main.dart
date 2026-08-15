import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get_it/get_it.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:one_remote/app/analytics/analytics_service.dart';
import 'package:one_remote/app/compliance/ad_consent_coordinator.dart';
import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/app/configurations/app_build_config.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/di_bootstrap.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/one_remote_app.dart';
import 'package:one_remote/app/stream_unhandled_error_source.dart';

StreamUnhandledErrorSource? _errorSource() {
  final sl = GetIt.instance;
  return sl.isRegistered<StreamUnhandledErrorSource>()
      ? sl<StreamUnhandledErrorSource>()
      : null;
}

void _recordUnhandledError(Object error) {
  final sl = GetIt.instance;
  if (sl.isRegistered<AppDiagnosticsRecorder>()) {
    sl<AppDiagnosticsRecorder>().recordUnhandledError(error);
  }
}

bool _supportsMobileAds() {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();

  final env = AppBuildConfig.environmentForMain();
  await DiBootstrap.initialize(env);
  GetIt.instance<AnalyticsService>().setCountryAtStartup(
    PlatformDispatcher.instance.locale,
  );
  final proEntitlementService = GetIt.instance<ProEntitlementService>();
  await proEntitlementService.applyLastKnownStatusFromCache();
  await proEntitlementService.refreshFromStore(isDebugBuild: kDebugMode);
  if (_supportsMobileAds()) {
    await AdConsentCoordinator.prepareForAds();
    if (AdConsentCoordinator.canRequestAds) {
      await MobileAds.instance.initialize();
    }
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    _recordUnhandledError(details.exception);
    final errorSource = _errorSource();
    if (errorSource != null) {
      errorSource.add(details.exception);
    } else if (env == AppEnvironment.debug) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    _recordUnhandledError(error);
    final errorSource = _errorSource();
    if (errorSource != null) {
      errorSource.add(error);
    } else if (env == AppEnvironment.debug) {
      debugPrint('Unhandled error: $error\n$stack');
    }
    return true;
  };

  runApp(const OneRemoteApp());
}
