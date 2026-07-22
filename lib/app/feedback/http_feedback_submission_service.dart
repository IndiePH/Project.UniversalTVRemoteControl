import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:one_remote/app/feedback/feedback_config.dart';
import 'package:one_remote/app/feedback/feedback_payload.dart';
import 'package:one_remote/app/feedback/feedback_submission_result.dart';
import 'package:one_remote/app/feedback/feedback_submission_service.dart';

/// POSTs feedback JSON to [FeedbackConfig.webhookUrl].
final class HttpFeedbackSubmissionService implements FeedbackSubmissionService {
  HttpFeedbackSubmissionService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<FeedbackSubmissionResult> submit(FeedbackPayload payload) async {
    final message = payload.message.trim();
    if (message.isEmpty) {
      return const FeedbackSubmissionResult.emptyMessage();
    }
    if (!FeedbackConfig.hasWebhookUrl) {
      return const FeedbackSubmissionResult.notConfigured();
    }

    final uri = Uri.parse(FeedbackConfig.webhookUrl.trim());
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (FeedbackConfig.hasWebhookToken) {
      headers['X-Feedback-Token'] = FeedbackConfig.webhookToken.trim();
    }

    try {
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(payload.toJson()))
          .timeout(const Duration(seconds: 20));
      if (await _isSuccessfulResponse(response)) {
        return const FeedbackSubmissionResult.success();
      }
      return const FeedbackSubmissionResult.networkError();
    } on Object {
      return const FeedbackSubmissionResult.networkError();
    }
  }

  /// Google Apps Script web apps return 302 after POST; package:http does not
  /// follow that redirect for POST, so we complete the chain with GET.
  Future<bool> _isSuccessfulResponse(http.Response response) async {
    if (_isHttpSuccess(response.statusCode)) {
      return _responseBodyIndicatesOk(response.body);
    }
    if (response.statusCode != 302 && response.statusCode != 303) {
      return false;
    }
    final location = response.headers['location']?.trim();
    if (location == null || location.isEmpty) {
      return false;
    }
    final follow = await _client
        .get(Uri.parse(location))
        .timeout(const Duration(seconds: 20));
    if (!_isHttpSuccess(follow.statusCode)) {
      return false;
    }
    return _responseBodyIndicatesOk(follow.body);
  }

  static bool _isHttpSuccess(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  static bool _responseBodyIndicatesOk(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return true;
    }
    if (trimmed.startsWith('<')) {
      return false;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final ok = decoded['ok'];
        if (ok is bool) {
          return ok;
        }
      }
    } on Object {
      return false;
    }
    return true;
  }
}
