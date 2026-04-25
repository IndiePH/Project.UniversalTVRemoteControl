abstract class Result {
  const Result({required this.message, this.exception});

  final String message;

  /// Raw exception from an unexpected failure; null on success or typed failures.
  /// Consumers should use [MessageHandler.sanitize] to produce a display string.
  final Object? exception;

  bool get isSuccess;
}
