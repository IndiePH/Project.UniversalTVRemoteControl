import 'package:one_remote/src/features/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

abstract class RemoteCommandService {
  Future<CommandDispatchResult> preparePairing({required TvDevice device});

  /// Submit a brand-specific pairing code shown on the TV (e.g. Hisense PIN).
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  });

  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  });

  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  });
}
