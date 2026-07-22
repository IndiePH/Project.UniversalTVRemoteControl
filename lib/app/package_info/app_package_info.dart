/// Installed app version metadata for diagnostics and feedback.
final class AppPackageInfo {
  const AppPackageInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  /// Display label sent with feedback (e.g. `1.0.0+1`).
  String get versionLabel => '$version+$buildNumber';
}
