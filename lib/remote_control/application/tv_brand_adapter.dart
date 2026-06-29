import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract class TvBrandAdapter {
  // Default body conventions used below:
  //   async {}                    — no-op is correct for some brands (optional lifecycle step)
  //   throw UnsupportedError      — calling without an override is a caller logic error
  //   null / false / disconnected — "not applicable" sentinel; caller handles gracefully

  TvBrand get brand;

  String get protocolVariant => TvDevice.defaultProtocolVariant;

  bool get supportsTextInput;
  Set<RemoteCommand> get supportedCommands;

  Future<void> preparePairing({required TvDevice device}) async {}

  Future<void> connect({required TvDevice device}) async {}

  /// Probes whether the TV is reachable on the network.
  /// Completes normally if reachable; throws if not.
  Future<void> probeConnection({required TvDevice device}) async =>
      throw UnsupportedError(
        'probeConnection not implemented for ${device.brand}',
      );

  /// Queries the TV for model and firmware information after pairing.
  /// Returns null if the brand's protocol does not support device probing.
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;

  /// Called when the user explicitly removes the device. Clears any persisted
  /// pairing credentials and resets transport state. No-op by default.
  Future<void> unpairDevice({required TvDevice device}) async {}

  /// Cancels an in-progress pairing attempt. Safe to call when no pairing is
  /// active. Overridden by adapters whose transport holds blocking state.
  Future<void> cancelPairing({required TvDevice device}) async {}

  /// Brand-specific step for pairing flows that require entering a TV code.
  Future<void> submitPairingCode({
    required TvDevice device,
    required String pinCode,
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

  /// Normalized connectivity state emitted by the brand transport.
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      Stream<ConnectionState>.value(ConnectionState.disconnected);
}
