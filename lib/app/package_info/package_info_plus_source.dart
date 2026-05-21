import 'package:one_remote/app/package_info/app_package_info.dart';
import 'package:one_remote/app/package_info/app_package_info_source.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Loads [AppPackageInfo] via [PackageInfo.fromPlatform].
final class PackageInfoPlusSource implements AppPackageInfoSource {
  PackageInfoPlusSource({AppPackageInfo? cached}) : _cached = cached;

  AppPackageInfo? _cached;

  @override
  Future<AppPackageInfo> getPackageInfo() async {
    final cached = _cached;
    if (cached != null) {
      return cached;
    }
    final info = await PackageInfo.fromPlatform();
    final resolved = AppPackageInfo(
      version: info.version,
      buildNumber: info.buildNumber,
    );
    _cached = resolved;
    return resolved;
  }
}
