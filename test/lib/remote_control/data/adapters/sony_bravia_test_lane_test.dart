import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_bravia_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/sony_bravia_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

void main() {
  const device = TvDevice(
    id: 'sony-bravia-test',
    displayName: 'Sony BRAVIA Test',
    brand: TvBrand.sony,
    protocolVariant: SonyProtocolVariants.braviaIpControl,
    capabilities: {DeviceCapability.keyCommands, DeviceCapability.powerControl},
    host: '192.168.1.32',
  );

  test('SonyBraviaAdapter: brand and protocolVariant identify Sony BRAVIA', () {
    final adapter = SonyBraviaAdapter(transportClient: _SpyBraviaTransportClient());
    expect(adapter.brand, TvBrand.sony);
    expect(adapter.protocolVariant, SonyProtocolVariants.braviaIpControl);
  });

  test('SonyBraviaAdapter: dpadUp sends the Up IRCC key', () async {
    final transport = _SpyBraviaTransportClient();
    final adapter = SonyBraviaAdapter(transportClient: transport);
    await adapter.sendCommand(device: device, command: RemoteCommand.dpadUp);
    expect(transport.sentKeys, ['Up']);
  });

  test(
    'SonyBraviaAdapter: power tries the TvPower alias after Power fails',
    () async {
      final transport = _SpyBraviaTransportClient()
        ..failingKeyCodes.add('Power');
      final adapter = SonyBraviaAdapter(transportClient: transport);
      await adapter.sendCommand(device: device, command: RemoteCommand.power);
      expect(transport.sentKeys, ['Power', 'TvPower']);
    },
  );

  test(
    'SonyBraviaAdapter: throws when every key alias fails, not silently',
    () async {
      final transport = _SpyBraviaTransportClient()
        ..failingKeyCodes.addAll(['Power', 'TvPower']);
      final adapter = SonyBraviaAdapter(transportClient: transport);
      await expectLater(
        adapter.sendCommand(device: device, command: RemoteCommand.power),
        throwsA(anything),
      );
    },
  );

  test(
    'SonyBraviaAdapter: playPause has no mapping (Play/Pause are not aliases)',
    () async {
      final adapter = SonyBraviaAdapter(transportClient: _SpyBraviaTransportClient());
      await expectLater(
        adapter.sendCommand(device: device, command: RemoteCommand.playPause),
        throwsUnsupportedError,
      );
    },
  );

  test('SonyBraviaAdapter: reachability probes the resolved host', () async {
    final transport = _SpyBraviaTransportClient();
    final adapter = SonyBraviaAdapter(transportClient: transport);
    await adapter.probeConnection(device: device);
    expect(transport.probedHost, '192.168.1.32');
  });

  test(
    'SonyBraviaAdapter: supportedCommands includes app-launch commands optimistically',
    () {
      final adapter = SonyBraviaAdapter(transportClient: _SpyBraviaTransportClient());
      expect(adapter.supportedCommands.contains(RemoteCommand.netflix), isTrue);
      expect(adapter.supportedCommands.contains(RemoteCommand.youtube), isTrue);
      expect(adapter.supportedCommands.contains(RemoteCommand.primeVideo), isTrue);
      expect(adapter.supportedCommands.contains(RemoteCommand.disneyPlus), isTrue);
      // playPause is deliberately unmapped — see key mapper doc comment.
      expect(adapter.supportedCommands.contains(RemoteCommand.playPause), isFalse);
    },
  );

  test(
    'SonyBraviaAdapter: netflix resolves the app URI by title and launches it',
    () async {
      final transport = _SpyBraviaTransportClient()
        ..appUriToReturn = 'com.sony.dtv.netflix.NetflixMainActivity';
      final adapter = SonyBraviaAdapter(transportClient: transport);
      await adapter.sendCommand(device: device, command: RemoteCommand.netflix);
      expect(transport.resolvedTitleQuery, 'netflix');
      expect(transport.launchedUri, 'com.sony.dtv.netflix.NetflixMainActivity');
      expect(transport.sentKeys, isEmpty);
    },
  );

  test(
    'SonyBraviaAdapter: netflix throws when the TV has no matching app installed',
    () async {
      final transport = _SpyBraviaTransportClient()..appUriToReturn = null;
      final adapter = SonyBraviaAdapter(transportClient: transport);
      await expectLater(
        adapter.sendCommand(device: device, command: RemoteCommand.netflix),
        throwsUnsupportedError,
      );
    },
  );
}

class _SpyBraviaTransportClient implements SonyBraviaTransportClient {
  final List<String> sentKeys = [];
  final Set<String> failingKeyCodes = {};
  String? probedHost;
  String? launchedUri;
  String? resolvedTitleQuery;
  String? appUriToReturn;

  @override
  Future<void> connect({required String deviceId}) async {}

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    sentKeys.add(keyCode);
    if (failingKeyCodes.contains(keyCode)) {
      throw Exception('simulated failure for $keyCode');
    }
  }

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId}) async =>
      const TvDeviceInfo(modelIdentifier: 'sony_bravia_ip_control');

  @override
  Future<void> probe(String host) async {
    probedHost = host;
  }

  @override
  Future<void> registerPin({required String deviceId, String? pin}) async {}

  @override
  Future<void> clearPairing({required String deviceId}) async {}

  @override
  Future<String?> resolveAppUri({
    required String deviceId,
    required String titleContains,
  }) async {
    resolvedTitleQuery = titleContains;
    return appUriToReturn;
  }

  @override
  Future<void> launchApp({
    required String deviceId,
    required String uri,
  }) async {
    launchedUri = uri;
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      Stream<ConnectionState>.value(ConnectionState.connected);

  @override
  Stream<TransportEvent> get events => const Stream<TransportEvent>.empty();
}
