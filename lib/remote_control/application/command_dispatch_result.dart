enum CommandOutcome { success, unsupported, failure, compatibility }

class CommandDispatchResult {
  const CommandDispatchResult._({
    required this.outcome,
    required this.message,
  });

  final CommandOutcome outcome;
  final String message;

  bool get isSuccess => outcome == CommandOutcome.success;

  const CommandDispatchResult.success(String message)
    : this._(outcome: CommandOutcome.success, message: message);

  const CommandDispatchResult.unsupported(String message)
    : this._(outcome: CommandOutcome.unsupported, message: message);

  const CommandDispatchResult.failure(String message)
    : this._(outcome: CommandOutcome.failure, message: message);

  const CommandDispatchResult.compatibility(String message)
    : this._(outcome: CommandOutcome.compatibility, message: message);
}
