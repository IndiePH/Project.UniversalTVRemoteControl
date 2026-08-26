import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_bravia_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_bravia_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/supported_remote_commands.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

/// Sony's own BRAVIA IP Control protocol — a second, independent protocol
/// from the Android TV Remote Protocol v2 path `SonyAdapter` covers. See
/// `guide-tv-remote-protocols.md`'s "Sony BRAVIA IP Control" section.
///
/// Experimental: PIN-mode auth only (no PSK entry UI yet), and app-launch
/// commands are resolved against each TV's own live app list rather than a
/// fixed table — see [_appLaunchTitles] and `sendCommand` below.
class SonyBraviaAdapter implements TvBrandAdapter {
  SonyBraviaAdapter({required this._transportClient})
    : _keyMap = const SonyBraviaKeyMapper();

  final SonyBraviaTransportClient _transportClient;
  final CommandKeyMap _keyMap;

  /// Commands resolved per-device against a live app list (`resolveAppUri`),
  /// not through [_keyMap] — see `sendCommand`. Keyed by the title substring
  /// to search each device's own `getApplicationList` response for; Netflix
  /// and YouTube are confirmed exact titles from real-device dumps, Prime
  /// Video/Disney+ are best-guess substrings pending on-device validation
  /// (see `guide-tv-remote-protocols.md`).
  static const Map<RemoteCommand, String> _appLaunchTitles = {
    RemoteCommand.netflix: 'netflix',
    RemoteCommand.youtube: 'youtube',
    RemoteCommand.primeVideo: 'prime video',
    RemoteCommand.disneyPlus: 'disney+',
  };

  @override
  TvBrand get brand => TvBrand.sony;

  @override
  String get protocolVariant => SonyProtocolVariants.braviaIpControl;

  @override
  bool get supportsTextInput => false;

  /// Live-computed rather than cached: app-launch entries are reported
  /// optimistically (a specific TV's actual app list can only be checked
  /// after connecting), so this can't be a fixed set the way every other
  /// adapter's `supportedCommands` is. A device missing one of these apps
  /// fails cleanly at send time (`resolveAppUri` returns null) rather than
  /// silently mis-dispatching.
  @override
  Set<RemoteCommand> get supportedCommands => {
    ...kCommonSupportedRemoteCommands.where(
      (command) => _keyMap.payloadFor(command) != null,
    ),
    ..._appLaunchTitles.keys,
  };

  @override
  Future<void> probeConnection({required TvDevice device}) =>
      _transportClient.probe(device.resolvedHost);

  @override
  Future<void> preparePairing({required TvDevice device}) =>
      _transportClient.registerPin(deviceId: device.id);

  @override
  Future<void> connect({required TvDevice device}) =>
      _transportClient.connect(deviceId: device.id);

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String pinCode,
  }) => _transportClient.registerPin(deviceId: device.id, pin: pinCode);

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) =>
      _transportClient.queryDeviceInfo(deviceId: device.id);

  @override
  Future<void> unpairDevice({required TvDevice device}) =>
      _transportClient.clearPairing(deviceId: device.id);

  @override
  Future<void> cancelPairing({required TvDevice device}) async {}

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    if (await _dispatchAppLaunch(device: device, command: command)) {
      return;
    }
    await _dispatchKeySequence(device: device, command: command);
  }

  /// Handles the app-launch commands (see [_appLaunchTitles]); returns
  /// `false` for every other command so [sendCommand] falls through to the
  /// normal [CommandPayload]-driven dispatch below.
  Future<bool> _dispatchAppLaunch({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final appTitle = _appLaunchTitles[command];
    if (appTitle == null) {
      return false;
    }
    final uri = await _transportClient.resolveAppUri(
      deviceId: device.id,
      titleContains: appTitle,
    );
    if (uri == null) {
      throw UnsupportedError(
        'Sony BRAVIA TV has no installed app matching "$appTitle".',
      );
    }
    await _transportClient.launchApp(deviceId: device.id, uri: uri);
    return true;
  }

  Future<void> _dispatchKeySequence({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final payload = _keyMap.payloadFor(command);
    if (payload == null) {
      throw UnsupportedError('No Sony BRAVIA key mapping for command: $command');
    }
    switch (payload) {
      case KeySequence(:final codes):
        await _sendFirstWorkingKey(device: device, codes: codes);
      case AppLink():
        throw UnsupportedError(
          'Sony BRAVIA dispatches app launch via resolveAppUri, not AppLink.',
        );
      case VidaaLaunch():
        throw UnsupportedError('Sony BRAVIA has no VidaaLaunch dispatch path.');
    }
  }

  /// Tries each alias in [codes] in order, stopping at the first the TV
  /// actually recognizes (see `sony_bravia_key_mapper.dart` — e.g. `Power`
  /// vs `TvPower` naming drift across firmwares).
  Future<void> _sendFirstWorkingKey({
    required TvDevice device,
    required List<String> codes,
  }) async {
    Object? lastError;
    for (final code in codes) {
      try {
        await _transportClient.sendKey(deviceId: device.id, keyCode: code);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError!;
  }

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {
    throw UnsupportedError('Text input is not supported for Sony BRAVIA.');
  }

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      Stream<bool>.value(false);

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      _transportClient.watchConnectionState(device.id);
}
