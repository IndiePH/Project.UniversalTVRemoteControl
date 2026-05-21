import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/configurations/i_di_config.dart';
import 'package:one_remote/app/feedback/feedback_submission_service.dart';
import 'package:one_remote/app/feedback/http_feedback_submission_service.dart';
import 'package:one_remote/app/package_info/app_package_info_source.dart';
import 'package:one_remote/app/package_info/package_info_plus_source.dart';

final class FeedbackDiConfig implements IDiConfig {
  const FeedbackDiConfig();

  @override
  void configure(GetIt sl, AppEnvironment env) {
    sl.registerLazySingleton<AppPackageInfoSource>(PackageInfoPlusSource.new);
    sl.registerLazySingleton<FeedbackSubmissionService>(
      HttpFeedbackSubmissionService.new,
    );
  }
}
