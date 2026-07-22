/// Google Sheets feedback webhook supplied at build time (Apps Script web app URL).
///
/// See `references/feedback-collection-setup.md`.
class FeedbackConfig {
  const FeedbackConfig._();

  /// HTTPS endpoint that accepts POST JSON feedback payloads.
  ///
  /// Override with `--dart-define=FEEDBACK_WEBHOOK_URL=https://...`.
  static const String webhookUrl = String.fromEnvironment(
    'FEEDBACK_WEBHOOK_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbyYdrlh8oVk1BwA2w5xa6JGW0kPwGSRaSElpqmClz2VyfhPpEX3rRvT3oTPbcS8w4HTWQ/exec',
  );

  /// Optional shared secret sent as `X-Feedback-Token` for simple webhook auth.
  ///
  /// Override with `--dart-define=FEEDBACK_WEBHOOK_TOKEN=...`.
  static const String webhookToken = String.fromEnvironment(
    'FEEDBACK_WEBHOOK_TOKEN',
    defaultValue: '',
  );

  static bool get hasWebhookUrl {
    final trimmed = webhookUrl.trim();
    return trimmed.startsWith('https://') || trimmed.startsWith('http://');
  }

  static bool get hasWebhookToken => webhookToken.trim().isNotEmpty;
}
