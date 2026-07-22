import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/compliance/app_legal_urls.dart';

void main() {
  test('hasPrivacyPolicyUrl is true with default hosted policy URL', () {
    expect(AppLegalUrls.hasPrivacyPolicyUrl, isTrue);
    expect(
      AppLegalUrls.privacyPolicyUrl,
      'https://yoxent.github.io/legal-docs/one-remote/privacy-policy.html',
    );
  });
}
