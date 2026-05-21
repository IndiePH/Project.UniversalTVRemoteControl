import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';

/// Shared abstraction that maps app commands to brand-specific key codes.
abstract class CommandKeyMap {
  const CommandKeyMap();

  List<String> keyCodesFor(RemoteCommand command);

  String? primaryKeyCodeFor(RemoteCommand command) {
    final keyCodes = keyCodesFor(command);
    if (keyCodes.isEmpty) {
      return null;
    }
    return keyCodes.first;
  }
}
