abstract class Result {
  const Result({required this.outcome, required this.message, this.exception});

  const Result.success({required String message})
    : outcome = 'success',
      message = message,
      exception = null;

  const Result.failure({required String message, Object? exception})
    : outcome = 'failure',
      message = message,
      exception = exception;

  final String outcome;
  final String message;

  /// Raw exception from an unexpected failure; null on success or typed failures.
  /// Consumers should use [MessageHandler.sanitize] to produce a display string.
  final Object? exception;

  bool get isSuccess;
}
