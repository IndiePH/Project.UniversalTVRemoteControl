import 'package:one_remote/remote_control/application/result.dart';
import 'package:one_remote/remote_control/domain/models/pin_format.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

enum CommandOutcome {
  success,
  unsupported,
  failure,
  compatibility,
  pinRequired,
}

class CommandDispatchResult extends Result {
  CommandDispatchResult.success(String message, {this.device})
    : pinFormat = PinFormat.fourDigitNumeric,
      super(outcome: CommandOutcome.success.name, message: message);

  CommandDispatchResult.unsupported(String message)
    : device = null,
      pinFormat = PinFormat.fourDigitNumeric,
      super(outcome: CommandOutcome.unsupported.name, message: message);

  CommandDispatchResult.failure(String message, {Object? exception})
    : device = null,
      pinFormat = PinFormat.fourDigitNumeric,
      super(
        outcome: CommandOutcome.failure.name,
        message: message,
        exception: exception,
      );

  CommandDispatchResult.compatibility(String message)
    : device = null,
      pinFormat = PinFormat.fourDigitNumeric,
      super(outcome: CommandOutcome.compatibility.name, message: message);

  /// Returned by [RemoteCommandService.preparePairing] when the transport
  /// handshake completed and the TV is displaying a PIN. The caller must
  /// collect the PIN and submit it via [RemoteCommandService.submitPairingCode].
  CommandDispatchResult.pinRequired(
    String message, {
    this.device,
    this.pinFormat = PinFormat.fourDigitNumeric,
  }) : super(outcome: CommandOutcome.pinRequired.name, message: message);

  /// Enriched device returned from [RemoteCommandService.preparePairing] when
  /// capabilities or protocol variant were resolved during pairing. Null for all
  /// other commands.
  final TvDevice? device;

  /// Format of the PIN the TV is displaying. Only meaningful when [isPinRequired].
  final PinFormat pinFormat;

  CommandOutcome getOutcome() => CommandOutcome.values.byName(outcome);

  @override
  bool get isSuccess => getOutcome() == CommandOutcome.success;

  bool get isPinRequired => getOutcome() == CommandOutcome.pinRequired;
}
