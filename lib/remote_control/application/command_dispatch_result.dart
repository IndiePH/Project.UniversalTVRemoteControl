import 'package:one_remote/remote_control/application/result.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

enum CommandOutcome { success, unsupported, failure, compatibility }

class CommandDispatchResult extends Result {

  CommandDispatchResult.success(String message, {this.device})
    : super(outcome: CommandOutcome.success.name, message: message);

  CommandDispatchResult.unsupported(String message)
    : device = null,
      super(outcome: CommandOutcome.unsupported.name, message: message);

  CommandDispatchResult.failure(String message, {Object? exception})
    : device = null,
      super(outcome: CommandOutcome.failure.name, message: message, exception: exception);

  CommandDispatchResult.compatibility(String message)
    : device = null,
      super(outcome: CommandOutcome.compatibility.name, message: message);

  /// Enriched device returned from [RemoteCommandService.preparePairing] when
  /// capabilities or protocol variant were resolved during pairing. Null for all
  /// other commands.
  final TvDevice? device;

  CommandOutcome getOutcome() => CommandOutcome.values.byName(outcome);

  @override
  bool get isSuccess => getOutcome() == CommandOutcome.success;
}
