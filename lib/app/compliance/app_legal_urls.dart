/// Public legal document URLs supplied at build time.
class AppLegalUrls {
  const AppLegalUrls._();

  /// Live privacy policy URL for store listings and in-app link.
  ///
  /// Override with `--dart-define=PRIVACY_POLICY_URL=https://...` if needed.
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue:
        'https://yoxent.github.io/legal-docs/one-remote/privacy-policy.html',
  );

  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.trim().isNotEmpty;
}
