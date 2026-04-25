import 'package:one_remote/remote_control/application/result.dart';

enum CommandOutcome { success, unsupported, failure, compatibility }

class CommandDispatchResult extends Result {
  const CommandDispatchResult._({
    required this.outcome,
    required super.message,
    super.exception,
  });

  final CommandOutcome outcome;

  @override
  bool get isSuccess => outcome == CommandOutcome.success;

  const CommandDispatchResult.success(String message)
    : this._(outcome: CommandOutcome.success, message: message);

  const CommandDispatchResult.unsupported(String message)
    : this._(outcome: CommandOutcome.unsupported, message: message);

  const CommandDispatchResult.failure(String message, {Object? exception})
    : this._(outcome: CommandOutcome.failure, message: message, exception: exception);

  const CommandDispatchResult.compatibility(String message)
    : this._(outcome: CommandOutcome.compatibility, message: message);
}
