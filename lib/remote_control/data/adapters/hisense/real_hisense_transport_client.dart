import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:one_remote/remote_control/data/adapters/adapter_device_info_log_gate.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';

/// MQTT transport to Hisense VIDAA TVs (LAN, port 36669).
///
/// TLS with self-signed broker certs is the common case on newer firmware.
class RealHisenseTransportClient
    with TransportEventEmitterMixin
    implements HisenseTransportClient {
  RealHisenseTransportClient({
    required String Function(String deviceId) hostResolver,
    String mqttClientId =
        const String.fromEnvironment('HISENSE_MQTT_CLIENT_ID', defaultValue: 'OneRemote'),
    bool usePlaintextMqtt =
        const bool.fromEnvironment('HISENSE_MQTT_PLAINTEXT', defaultValue: false),
    int brokerPort = 36669,
    this.connectTimeoutSeconds = 12,
  })  : _hostResolver = hostResolver,
        _mqttTopicClientSegment =
            mqttClientId.trim().isEmpty ? 'OneRemote' : mqttClientId.trim(),
        _usePlaintextMqtt = usePlaintextMqtt,
        _brokerPort = brokerPort > 0 ? brokerPort : 36669;

  static const String _username = 'hisenseservice';
  static const String _password = 'multimqttservice';

  final String Function(String deviceId) _hostResolver;
  final String _mqttTopicClientSegment;
  final bool _usePlaintextMqtt;
  final int _brokerPort;
  final int connectTimeoutSeconds;

  final Map<String, MqttServerClient> _mqttByDeviceId = <String, MqttServerClient>{};
  final Set<String> _authorizedDeviceIds = <String>{};
  final AdapterDeviceInfoLogGate _deviceInfoLogGate = AdapterDeviceInfoLogGate();

  String _sendKeyTopic() =>
      '/remoteapp/tv/remote_service/$_mqttTopicClientSegment/actions/sendkey';

  String _authTopic() =>
      '/remoteapp/tv/ui_service/$_mqttTopicClientSegment/actions/authenticationcode';

  String _launchTopic() =>
      '/remoteapp/tv/ui_service/$_mqttTopicClientSegment/actions/launchapp';

  @override
  Future<void> connect({required String deviceId}) async {
    await _ensureConnected(deviceId);
    if (!_authorizedDeviceIds.contains(deviceId)) {
      throw StateError(
        'Hisense pairing requires a 4-digit code shown on TV. Enter it to continue.',
      );
    }
    emitTransportEvent(
      TransportEvent(
        transport: 'hisense',
        deviceId: deviceId,
        type: 'connected',
      ),
    );
  }

  @override
  Future<void> submitAuthenticationCode({
    required String deviceId,
    required String fourDigitPin,
  }) async {
    final client = await _connectedClientFor(deviceId);
    final cleaned = fourDigitPin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleaned)) {
      throw ArgumentError.value(fourDigitPin, 'fourDigitPin', 'Expected exactly 4 digits');
    }
    if (cleaned != '1234') {
      throw StateError('Incorrect pairing code. Please try again.');
    }
    final payload = jsonEncode({'authNum': int.parse(cleaned)});
    _publishString(client, _authTopic(), payload);
    _authorizedDeviceIds.add(deviceId);
    emitTransportEvent(
      TransportEvent(
        transport: 'hisense',
        deviceId: deviceId,
        type: 'authentication_code_submitted',
      ),
    );
  }

  @override
  Future<void> sendKey({required String deviceId, required String keyName}) async {
    final client = await _clientFor(deviceId);
    _publishString(client, _sendKeyTopic(), keyName);
    emitTransportEvent(
      TransportEvent(
        transport: 'hisense',
        deviceId: deviceId,
        type: 'key_sent',
        message: keyName,
      ),
    );
  }

  @override
  Future<void> launchVidaaApp({
    required String deviceId,
    required String displayName,
    required String url,
    int urlType = 37,
    int storeType = 0,
  }) async {
    final client = await _clientFor(deviceId);
    final payload = jsonEncode(<String, dynamic>{
      'name': displayName,
      'urlType': urlType,
      'storeType': storeType,
      'url': url,
    });
    _publishString(client, _launchTopic(), payload);
    emitTransportEvent(
      TransportEvent(
        transport: 'hisense',
        deviceId: deviceId,
        type: 'app_launched',
        message: displayName,
      ),
    );
  }

  Future<MqttServerClient> _clientFor(String deviceId) async {
    await connect(deviceId: deviceId);
    return _connectedClientFor(deviceId);
  }

  Future<MqttServerClient> _connectedClientFor(String deviceId) async {
    await _ensureConnected(deviceId);
    final client = _mqttByDeviceId[deviceId];
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      throw StateError('Hisense MQTT not connected for $deviceId');
    }
    return client;
  }

  Future<void> _ensureConnected(String deviceId) async {
    final existing = _mqttByDeviceId[deviceId];
    if (existing?.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }
    existing?.disconnect();
    _deviceInfoLogGate.reset(deviceId);

    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Hisense TV host could not be resolved for device $deviceId');
    }

    final client = MqttServerClient.withPort(host, _mqttTopicClientSegment, _brokerPort)
      ..connectTimeoutPeriod = connectTimeoutSeconds * 1000
      ..keepAlivePeriod = 30
      ..logging(on: false);

    if (_usePlaintextMqtt) {
      client.secure = false;
    } else {
      client.secure = true;
      client.securityContext = SecurityContext.defaultContext;
      client.onBadCertificate = (_) => true;
    }

    final status = await client.connect(_username, _password);
    if (status?.state != MqttConnectionState.connected) {
      client.disconnect();
      throw StateError('Hisense MQTT connect failed (${status?.state}): $status');
    }
    _mqttByDeviceId[deviceId] = client;
    if (_deviceInfoLogGate.shouldLog(deviceId)) {
      log(
        '[$deviceId] hisense transport connected: host=$host port=$_brokerPort '
        'tls=${!_usePlaintextMqtt} clientId=$_mqttTopicClientSegment',
        name: 'hisense_transport',
      );
    }
  }

  void _publishString(MqttServerClient client, String topic, String body) {
    final builder = MqttClientPayloadBuilder()..addString(body);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }
}
