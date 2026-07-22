import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_legacy_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/tcl_legacy_wifi_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

void main() {
  const device = TvDevice(
    id: 'tcl-tcl_legacy_wifi-192.168.1.31',
    displayName: 'TCL Legacy TV',
    brand: TvBrand.tcl,
    protocolVariant: 'tcl_legacy_wifi',
    capabilities: {DeviceCapability.keyCommands, DeviceCapability.powerControl},
  );

  test('TclLegacyWifiAdapter sends legacy frame for menu', () async {
    final transport = _SpyLegacyTransportClient();
    final adapter = TclLegacyWifiAdapter(transportClient: transport);
    await adapter.sendCommand(device: device, command: RemoteCommand.menu);
    expect(transport.frames, ['KEY_MENU']);
  });
}

class _SpyLegacyTransportClient implements TclLegacyTransportClient {
  final List<String> frames = <String>[];

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
  Future<void> probe(String host) async {}

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId}) async =>
      const TvDeviceInfo(modelIdentifier: 'tcl_legacy_wifi');

  @override
  Future<void> sendFrame({
    required String deviceId,
    required String frame,
  }) async {
    frames.add(frame);
  }
}
