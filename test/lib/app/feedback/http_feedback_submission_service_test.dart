import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_remote/app/feedback/feedback_config.dart';
import 'package:one_remote/app/feedback/feedback_payload.dart';
import 'package:one_remote/app/feedback/feedback_submission_result.dart';
import 'package:one_remote/app/feedback/http_feedback_submission_service.dart';

FeedbackPayload _samplePayload({String message = 'Enough text here.'}) =>
    FeedbackPayload(
      message: message,
      category: 'suggestion',
      platform: 'android',
      appVersion: '1.0.0+1',
      submittedAtUtc: DateTime.utc(2026, 5, 21),
    );

void main() {
  test('returns emptyMessage when message is blank', () async {
    final service = HttpFeedbackSubmissionService();
    final result = await service.submit(_samplePayload(message: '   '));
    expect(result.outcome, FeedbackSubmissionOutcome.emptyMessage);
  });

  test('hasWebhookUrl is true with default deployment URL', () {
    expect(FeedbackConfig.hasWebhookUrl, isTrue);
  });

  test(
    'succeeds when POST returns 302 and follow-up GET returns ok JSON',
    () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            'Moved',
            302,
            headers: {'location': 'https://script.googleusercontent.com/echo'},
          );
        }
        return http.Response('{"ok":true}', 200);
      });
      final service = HttpFeedbackSubmissionService(client: client);
      final result = await service.submit(_samplePayload());
      expect(result.outcome, FeedbackSubmissionOutcome.success);
    },
  );

  test('returns networkError when follow-up GET reports ok false', () async {
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(
          'Moved',
          302,
          headers: {'location': 'https://script.googleusercontent.com/echo'},
        );
      }
      return http.Response('{"ok":false,"error":"unauthorized"}', 200);
    });
    final service = HttpFeedbackSubmissionService(client: client);
    final result = await service.submit(_samplePayload());
    expect(result.outcome, FeedbackSubmissionOutcome.networkError);
  });

  test('succeeds on direct 200 JSON ok without redirect', () async {
    final client = MockClient((_) async => http.Response('{"ok":true}', 200));
    final service = HttpFeedbackSubmissionService(client: client);
    final result = await service.submit(_samplePayload());
    expect(result.outcome, FeedbackSubmissionOutcome.success);
  });
}
