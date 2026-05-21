import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/package_info/app_package_info.dart';
import 'package:one_remote/app/package_info/package_info_plus_source.dart';

void main() {
  test('returns cached package info without calling platform', () async {
    const info = AppPackageInfo(version: '2.0.0', buildNumber: '99');
    final source = PackageInfoPlusSource(cached: info);

    expect(await source.getPackageInfo(), info);
    expect(await source.getPackageInfo(), info);
  });

  test('versionLabel formats version and build', () {
    const info = AppPackageInfo(version: '1.0.0', buildNumber: '1');
    expect(info.versionLabel, '1.0.0+1');
  });
}
