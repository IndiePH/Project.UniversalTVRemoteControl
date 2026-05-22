/// Outcome of an in-app feedback submission attempt.
enum FeedbackSubmissionOutcome {
  success,
  emptyMessage,
  notConfigured,
  networkError,
}

final class FeedbackSubmissionResult {
  const FeedbackSubmissionResult._(this.outcome);

  const FeedbackSubmissionResult.success()
    : this._(FeedbackSubmissionOutcome.success);

  const FeedbackSubmissionResult.emptyMessage()
    : this._(FeedbackSubmissionOutcome.emptyMessage);

  const FeedbackSubmissionResult.notConfigured()
    : this._(FeedbackSubmissionOutcome.notConfigured);

  const FeedbackSubmissionResult.networkError()
    : this._(FeedbackSubmissionOutcome.networkError);

  final FeedbackSubmissionOutcome outcome;

  bool get isSuccess => outcome == FeedbackSubmissionOutcome.success;
}
