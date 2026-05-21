import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/compliance/app_legal_urls.dart';

void main() {
  test('hasPrivacyPolicyUrl is false when PRIVACY_POLICY_URL is unset', () {
    expect(AppLegalUrls.hasPrivacyPolicyUrl, isFalse);
  });
}
