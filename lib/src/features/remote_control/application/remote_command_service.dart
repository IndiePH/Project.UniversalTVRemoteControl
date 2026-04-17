import 'package:one_remote/src/features/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

abstract class RemoteCommandService {
  Future<CommandDispatchResult> preparePairing({required TvDevice device});

  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  });

  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  });
}
