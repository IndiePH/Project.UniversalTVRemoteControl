/// User feedback submitted from the in-app form.
final class FeedbackPayload {
  const FeedbackPayload({
    required this.message,
    required this.category,
    required this.platform,
    required this.appVersion,
    required this.submittedAtUtc,
  });

  final String message;
  final String category;
  final String platform;
  final String appVersion;
  final DateTime submittedAtUtc;

  Map<String, Object> toJson() => {
    'message': message,
    'category': category,
    'platform': platform,
    'appVersion': appVersion,
    'submittedAt': submittedAtUtc.toIso8601String(),
  };
}
