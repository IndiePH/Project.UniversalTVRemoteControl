import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/feedback/feedback_config.dart';

void main() {
  test('webhook is configured with default Apps Script deployment URL', () {
    expect(FeedbackConfig.hasWebhookUrl, isTrue);
    expect(
      FeedbackConfig.webhookUrl,
      contains('AKfycbxx5TXjDYZ2hEl-IdqEGHB0Q776pVR90q2iIEFePRISOINcIfq9eoBKOjS87N2F-dlg'),
    );
  });
}
