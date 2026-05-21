class CommandDispatchResult {
  const CommandDispatchResult._({
    required this.isSuccess,
    required this.message,
    this.isCompatibilityIssue = false,
  });

  final bool isSuccess;
  final String message;

  /// True when sending failed because the TV app or screen does not support
  /// remote text injection (distinct from transport or generic errors).
  final bool isCompatibilityIssue;

  const CommandDispatchResult.success(String message)
    : this._(isSuccess: true, message: message);

  const CommandDispatchResult.unsupported(String message)
    : this._(isSuccess: false, message: message);

  const CommandDispatchResult.failure(String message)
    : this._(isSuccess: false, message: message);

  const CommandDispatchResult.compatibility(String message)
    : this._(
        isSuccess: false,
        message: message,
        isCompatibilityIssue: true,
      );
}
