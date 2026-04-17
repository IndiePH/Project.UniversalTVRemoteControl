import 'package:universal_tv_remove_control/src/features/remote_control/application/command_dispatch_result.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/remote_command.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_device.dart';

abstract class RemoteCommandService {
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  });

  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  });
}
