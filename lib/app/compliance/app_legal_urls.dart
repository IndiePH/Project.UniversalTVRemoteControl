/// Public legal document URLs supplied at build time.
class AppLegalUrls {
  const AppLegalUrls._();

  /// Live privacy policy URL for store listings and in-app link.
  ///
  /// Set via `--dart-define=PRIVACY_POLICY_URL=https://...` on release builds.
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: '',
  );

  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.trim().isNotEmpty;
}
