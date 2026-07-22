import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/feedback/feedback_payload.dart';

void main() {
  test('toJson includes appVersion', () {
    final json = FeedbackPayload(
      message: 'Layout edit is confusing.',
      category: 'suggestion',
      platform: 'android',
      appVersion: '1.0.0+1',
      submittedAtUtc: DateTime.utc(2026, 5, 21, 12),
    ).toJson();

    expect(json['appVersion'], '1.0.0+1');
    expect(json['platform'], 'android');
    expect(json['message'], 'Layout edit is confusing.');
  });
}
