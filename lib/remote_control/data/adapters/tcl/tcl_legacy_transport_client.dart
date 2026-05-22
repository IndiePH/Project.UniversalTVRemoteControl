import 'package:one_remote/remote_control/data/adapters/transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_source.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract class TclLegacyTransportClient
    implements TransportClient, TransportEventSource {
  Future<void> connect({required String deviceId});

  Future<void> sendFrame({required String deviceId, required String frame});

  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId});

  Future<void> probe(String host);

  Future<void> clearPairing({required String deviceId});
}
