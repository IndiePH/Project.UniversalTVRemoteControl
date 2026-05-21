import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/compliance/legal_link_launcher.dart';

void main() {
  test('rejects invalid URLs', () async {
    expect(await LegalLinkLauncher.openUrl(''), isFalse);
    expect(await LegalLinkLauncher.openUrl('not-a-url'), isFalse);
    expect(await LegalLinkLauncher.openUrl('javascript:alert(1)'), isFalse);
  });
}
