import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Evaluates whether remote keyboard entry can be used for a device/action.
///
/// Keeps keyboard availability policy in one place so UI handlers only deal
/// with rendering feedback and navigation.
final class RemoteKeyboardAvailability {
  const RemoteKeyboardAvailability._({
    required this.isAvailable,
    this.unavailableReason,
  });

  static const String unavailableMessage =
      "Remote keyboard can't be used on this screen or with this TV.";

  final bool isAvailable;
  final RemoteKeyboardUnavailableReason? unavailableReason;

  static const RemoteKeyboardAvailability available =
      RemoteKeyboardAvailability._(isAvailable: true);

  static RemoteKeyboardAvailability evaluate({
    required TvDevice device,
    required bool remoteTextInputReady,
    required bool requireImeReady,
  }) {
    if (!device.capabilities.contains(DeviceCapability.textInput)) {
      return const RemoteKeyboardAvailability._(
        isAvailable: false,
        unavailableReason:
            RemoteKeyboardUnavailableReason.noTextInputCapability,
      );
    }
    if (requireImeReady && !remoteTextInputReady) {
      return const RemoteKeyboardAvailability._(
        isAvailable: false,
        unavailableReason: RemoteKeyboardUnavailableReason.remoteImeNotReady,
      );
    }
    return available;
  }

  /// Returns a concise diagnostic line for debug logs.
  String toDebugLog({required String action, required String deviceId}) {
    switch (unavailableReason) {
      case RemoteKeyboardUnavailableReason.noTextInputCapability:
        return '[OneRemote] keyboard $action: no textInput capability device=$deviceId';
      case RemoteKeyboardUnavailableReason.remoteImeNotReady:
        return '[OneRemote] keyboard $action: remote IME not ready device=$deviceId';
      case null:
        return '[OneRemote] keyboard $action: available device=$deviceId';
    }
  }
}

enum RemoteKeyboardUnavailableReason {
  noTextInputCapability,
  remoteImeNotReady,
}
