import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/remote_command.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:universal_tv_remove_control/src/features/remote_control/domain/models/tv_device.dart';

abstract class TvBrandAdapter {
  TvBrand get brand;
  bool get supportsTextInput;
  Set<RemoteCommand> get supportedCommands;

  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  });

  Future<void> sendText({
    required TvDevice device,
    required String text,
  });
}
