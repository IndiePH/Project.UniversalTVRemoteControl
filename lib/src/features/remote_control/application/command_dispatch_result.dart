class CommandDispatchResult {
  const CommandDispatchResult._({
    required this.isSuccess,
    required this.message,
  });

  final bool isSuccess;
  final String message;

  const CommandDispatchResult.success(String message)
    : this._(isSuccess: true, message: message);

  const CommandDispatchResult.unsupported(String message)
    : this._(isSuccess: false, message: message);

  const CommandDispatchResult.failure(String message)
    : this._(isSuccess: false, message: message);
}
