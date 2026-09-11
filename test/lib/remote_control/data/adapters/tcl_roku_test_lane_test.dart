import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/roku_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl_roku_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/key_hold_phase.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

void main() {
  const device = TvDevice(
    id: 'roku-192.168.1.30',
    displayName: 'Roku TV',
    brand: TvBrand.roku,
    protocolVariant: TvDevice.defaultProtocolVariant,
    capabilities: {DeviceCapability.keyCommands, DeviceCapability.powerControl},
  );

  test('TclRokuAdapter sends Roku key for dpad up', () async {
    final transport = _SpyRokuTransportClient();
    final adapter = TclRokuAdapter(transportClient: transport);
    await adapter.sendCommand(device: device, command: RemoteCommand.dpadUp);
    expect(transport.sentKeys, ['Up']);
  });

  test('TclRokuAdapter launches apps for app shortcut commands', () async {
    final transport = _SpyRokuTransportClient();
    final adapter = TclRokuAdapter(transportClient: transport);
    await adapter.sendCommand(device: device, command: RemoteCommand.netflix);
    expect(transport.launchedApps, ['12']);
  });

  test('TclRokuAdapter: supportsKeyHold is true', () {
    final adapter = TclRokuAdapter(transportClient: _SpyRokuTransportClient());
    expect(adapter.supportsKeyHold, isTrue);
  });

  test('TclRokuAdapter: sendKeyHold calls keydown then keyup via the resolved '
      'key code', () async {
    final transport = _SpyRokuTransportClient();
    final adapter = TclRokuAdapter(transportClient: transport);
    await adapter.sendKeyHold(
      device: device,
      command: RemoteCommand.dpadOk,
      phase: KeyHoldPhase.down,
    );
    await adapter.sendKeyHold(
      device: device,
      command: RemoteCommand.dpadOk,
      phase: KeyHoldPhase.up,
    );
    expect(transport.sentKeyHolds, [
      ('Select', KeyHoldPhase.down),
      ('Select', KeyHoldPhase.up),
    ]);
  });

  test(
    'TclRokuAdapter: sendKeyHold throws for a command with no key mapping',
    () async {
      final transport = _SpyRokuTransportClient();
      final adapter = TclRokuAdapter(transportClient: transport);
      await expectLater(
        adapter.sendKeyHold(
          device: device,
          command: RemoteCommand.netflix,
          phase: KeyHoldPhase.down,
        ),
        throwsUnsupportedError,
      );
    },
  );
}

class _SpyRokuTransportClient implements RokuTransportClient {
  final List<String> sentKeys = <String>[];
  final List<String> launchedApps = <String>[];
  final List<(String, KeyHoldPhase)> sentKeyHolds = <(String, KeyHoldPhase)>[];

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<void> launchApp({
    required String deviceId,
    required String appId,
  }) async {
    launchedApps.add(appId);
  }

  @override
  Future<void> probe(String host) async {}

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId}) async =>
      const TvDeviceInfo(modelIdentifier: 'roku');

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    sentKeys.add(keyCode);
  }

  @override
  Future<void> sendKeyHold({
    required String deviceId,
    required String keyCode,
    required KeyHoldPhase phase,
  }) async {
    sentKeyHolds.add((keyCode, phase));
  }
}
