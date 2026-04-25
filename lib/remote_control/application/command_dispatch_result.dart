import 'package:one_remote/remote_control/application/result.dart';

enum CommandOutcome { success, unsupported, failure, compatibility }

class CommandDispatchResult extends Result {
  
  CommandDispatchResult.success(String message)
    : super(outcome: CommandOutcome.success.name, message: message);

  CommandDispatchResult.unsupported(String message)
    : super(outcome: CommandOutcome.unsupported.name, message: message);

  CommandDispatchResult.failure(String message, {Object? exception})
    : super(outcome: CommandOutcome.failure.name, message: message, exception: exception);

  CommandDispatchResult.compatibility(String message)
    : super(outcome: CommandOutcome.compatibility.name, message: message);

  CommandOutcome getOutcome() => CommandOutcome.values.byName(outcome);

  @override
  bool get isSuccess => getOutcome() == CommandOutcome.success;
}
