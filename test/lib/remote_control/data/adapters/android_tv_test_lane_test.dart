import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv_adapter.dart';
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
    expect(mapper.keyCodesFor(RemoteCommand.menu), ['82', '176']);
  });

  test('AndroidTvAdapter: menu publishes fallback key codes in order', () async {
    final transport = _SpyAndroidTvTransportClient();
    final adapter = AndroidTvAdapter(transportClient: transport);
    await adapter.sendCommand(device: device, command: RemoteCommand.menu);
    expect(transport.sentKeys, containsAllInOrder(['82', '176']));
  });
}

class _SpyAndroidTvTransportClient implements AndroidTvTransportClient {
  int connectCalls = 0;
  final List<String> sentKeys = [];

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
  Future<void> sendKey({required String deviceId, required String keyCode}) async {
    sentKeys.add(keyCode);
  }

  @override
  Future<void> sendText({required String deviceId, required String text}) async {}

  @override
  Future<void> sendAppLink({
    required String deviceId,
    required String appLink,
  }) async {}

  @override
  Future<void> probe(String host) async {}

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
