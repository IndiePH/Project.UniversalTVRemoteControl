import 'package:one_remote/app/package_info/app_package_info.dart';

/// Provides installed app version metadata.
abstract class AppPackageInfoSource {
  Future<AppPackageInfo> getPackageInfo();
}
