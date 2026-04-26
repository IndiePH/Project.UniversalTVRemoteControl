import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract class TvBrandAdapter {
  TvBrand get brand;

  String get protocolVariant => TvDevice.defaultProtocolVariant;

  bool get supportsTextInput;
  Set<RemoteCommand> get supportedCommands;

  Future<void> preparePairing({required TvDevice device}) async {}

  /// Probes whether the TV is reachable on the network.
  /// Completes normally if reachable; throws if not.
  Future<void> probeConnection({required TvDevice device}) async =>
      throw UnsupportedError('probeConnection not implemented for ${device.brand}');

  /// Queries the TV for model and firmware information after pairing.
  /// Returns null if the brand's protocol does not support device probing.
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;

  /// Called when the user explicitly removes the device. Clears any persisted
  /// pairing credentials and resets transport state. No-op by default.
  Future<void> unpairDevice({required TvDevice device}) async {}

  /// Brand-specific step for pairing flows that require entering a TV code.
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    throw UnsupportedError(
      'Pairing code flow is not supported for ${device.brand.name}.',
    );
  }

  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  });

  Future<void> sendText({required TvDevice device, required String text});

  /// Whether the TV UI currently accepts remote-typed text (IME / protocol-specific).
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);
}
