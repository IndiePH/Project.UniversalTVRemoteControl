import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/feedback/feedback_config.dart';

void main() {
  test('webhook is configured with default Apps Script deployment URL', () {
    expect(FeedbackConfig.hasWebhookUrl, isTrue);
    expect(
      FeedbackConfig.webhookUrl,
      contains(
        'AKfycbyYdrlh8oVk1BwA2w5xa6JGW0kPwGSRaSElpqmClz2VyfhPpEX3rRvT3oTPbcS8w4HTWQ',
      ),
    );
  });
}
