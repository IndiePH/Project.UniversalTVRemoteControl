import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/key_hold_phase.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

void main() {
  const mapper = AndroidTvKeyMapper();
  const device = TvDevice(
    id: 'android-tv-test',
    displayName: 'Android TV Test',
    brand: TvBrand.androidTv,
    capabilities: {
      DeviceCapability.keyCommands,
      DeviceCapability.textInput,
      DeviceCapability.powerControl,
    },
  );

  test('AndroidTvKeyMapper: menu returns fallback key codes', () {
    expect(
      mapper.payloadFor(RemoteCommand.menu),
      const KeySequence(['82', '176']),
    );
  });

  test(
    'AndroidTvAdapter: menu publishes fallback key codes in order',
    () async {
      final transport = _SpyAndroidTvTransportClient();
      final adapter = AndroidTvAdapter(transportClient: transport);
      await adapter.sendCommand(device: device, command: RemoteCommand.menu);
      expect(transport.sentKeys, containsAllInOrder(['82', '176']));
    },
  );

  test('AndroidTvAdapter: reachability probes the resolved host', () async {
    final transport = _SpyAndroidTvTransportClient();
    final adapter = AndroidTvAdapter(transportClient: transport);
    const device = TvDevice(
      id: 'androidtv-certificate-hash',
      displayName: 'Android TV Test',
      brand: TvBrand.androidTv,
      capabilities: {
        DeviceCapability.keyCommands,
        DeviceCapability.textInput,
        DeviceCapability.powerControl,
      },
      host: '192.168.1.30',
    );

    await adapter.probeConnection(device: device);

    expect(transport.probedHost, '192.168.1.30');
  });

  test('AndroidTvAdapter: supportsKeyHold is true', () {
    final adapter = AndroidTvAdapter(
      transportClient: _SpyAndroidTvTransportClient(),
    );
    expect(adapter.supportsKeyHold, isTrue);
  });

  test('AndroidTvAdapter: sendKeyHold sends START_LONG then END_LONG via the '
      'resolved key code', () async {
    final transport = _SpyAndroidTvTransportClient();
    final adapter = AndroidTvAdapter(transportClient: transport);
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
      ('23', KeyHoldPhase.down),
      ('23', KeyHoldPhase.up),
    ]);
  });

  test(
    'AndroidTvAdapter: sendKeyHold throws for a command with no key mapping',
    () async {
      final transport = _SpyAndroidTvTransportClient();
      final adapter = AndroidTvAdapter(transportClient: transport);
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

class _SpyAndroidTvTransportClient implements AndroidTvTransportClient {
  int connectCalls = 0;
  final List<String> sentKeys = [];
  final List<(String, KeyHoldPhase)> sentKeyHolds = [];
  String? probedHost;

  @override
  Future<void> connect({required String deviceId}) async {
    connectCalls++;
  }

  @override
  Future<void> submitPairingCode({
    required String deviceId,
    required String code,
  }) async {}

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

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {}

  @override
  Future<void> sendAppLink({
    required String deviceId,
    required String appLink,
  }) async {}

  @override
  Future<void> probe(String host) async {
    probedHost = host;
  }

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  void cancelPairing(String deviceId) {}

  @override
  Future<TvDeviceInfo> queryDeviceInfo({required String deviceId}) async =>
      const TvDeviceInfo();

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}
