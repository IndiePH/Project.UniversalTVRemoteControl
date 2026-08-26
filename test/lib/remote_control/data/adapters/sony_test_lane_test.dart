import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/command_key_map.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/sony_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

void main() {
  const mapper = AndroidTvKeyMapper();
  const device = TvDevice(
    id: 'sony-test',
    displayName: 'Sony Test',
    brand: TvBrand.sony,
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

  test('SonyAdapter: brand and protocolVariant identify Sony', () {
    final adapter = SonyAdapter(transportClient: _SpySonyTransportClient());
    expect(adapter.brand, TvBrand.sony);
    expect(adapter.protocolVariant, SonyProtocolVariants.defaultVariant);
  });

  test('SonyAdapter: menu publishes fallback key codes in order', () async {
    final transport = _SpySonyTransportClient();
    final adapter = SonyAdapter(transportClient: transport);
    await adapter.sendCommand(device: device, command: RemoteCommand.menu);
    expect(transport.sentKeys, containsAllInOrder(['82', '176']));
  });

  test('SonyAdapter: reachability probes the resolved host', () async {
    final transport = _SpySonyTransportClient();
    final adapter = SonyAdapter(transportClient: transport);
    const device = TvDevice(
      id: 'sony-certificate-hash',
      displayName: 'Sony Test',
      brand: TvBrand.sony,
      capabilities: {
        DeviceCapability.keyCommands,
        DeviceCapability.textInput,
        DeviceCapability.powerControl,
      },
      host: '192.168.1.31',
    );

    await adapter.probeConnection(device: device);

    expect(transport.probedHost, '192.168.1.31');
  });

  test(
    'SonyAdapter: no app-link override — uses AndroidTvKeyMapper default https:// links',
    () {
      final adapter = SonyAdapter(transportClient: _SpySonyTransportClient());
      expect(adapter.supportedCommands.contains(RemoteCommand.netflix), isTrue);
    },
  );
}

class _SpySonyTransportClient implements AndroidTvTransportClient {
  int connectCalls = 0;
  final List<String> sentKeys = [];
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
