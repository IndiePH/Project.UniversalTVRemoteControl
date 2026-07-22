abstract class Result {
  const Result({required this.outcome, required this.message, this.exception});

  const Result.success({required this.message})
    : outcome = 'success',
      exception = null;

  const Result.failure({required this.message, this.exception})
    : outcome = 'failure';

  final String outcome;
  final String message;

  /// Raw exception from an unexpected failure; null on success or typed failures.
  /// Consumers should use [MessageHandler.sanitize] to produce a display string.
  final Object? exception;

  bool get isSuccess;
}
