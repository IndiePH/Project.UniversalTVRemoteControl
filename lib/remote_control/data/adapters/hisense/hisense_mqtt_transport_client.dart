import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:one_remote/remote_control/application/pin_required_exception.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/data/adapters/adapter_device_info_log_gate.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';

/// MQTT transport to Hisense VIDAA TVs (LAN, port 36669).
///
/// TLS with self-signed broker certs is the common case on newer firmware.
class HisenseMqttTransportClient
    with TransportEventEmitterMixin
    implements HisenseTransportClient {
  HisenseMqttTransportClient({
    required String Function(String deviceId) hostResolver,
    String mqttClientId = const String.fromEnvironment(
      'HISENSE_MQTT_CLIENT_ID',
      defaultValue: 'OneRemote',
    ),
    bool usePlaintextMqtt = const bool.fromEnvironment(
      'HISENSE_MQTT_PLAINTEXT',
      defaultValue: false,
    ),
    String textTopic = const String.fromEnvironment(
      'HISENSE_MQTT_TEXT_TOPIC',
      defaultValue: '',
    ),
    int brokerPort = 36669,
    this.connectTimeoutSeconds = 12,
  }) : _hostResolver = hostResolver,
       _mqttTopicClientSegment = mqttClientId.trim().isEmpty
           ? 'OneRemote'
           : mqttClientId.trim(),
       _usePlaintextMqtt = usePlaintextMqtt,
       _textTopic = textTopic.trim(),
       _brokerPort = brokerPort > 0 ? brokerPort : 36669;

  static const String _username = 'hisenseservice';
  static const String _password = 'multimqttservice';

  final String Function(String deviceId) _hostResolver;
  final String _mqttTopicClientSegment;
  final bool _usePlaintextMqtt;
  final String _textTopic;
  final int _brokerPort;
  final int connectTimeoutSeconds;

  final Map<String, MqttServerClient> _mqttByDeviceId =
      <String, MqttServerClient>{};
  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      <String, StreamController<ConnectionState>>{};
  final Map<String, ConnectionState> _lastConnectionStates =
      <String, ConnectionState>{};
  final Map<String, Timer> _connectivityPollTimers = <String, Timer>{};
  final Set<String> _authorizedDeviceIds = <String>{};
  // Guards _pollConnectivity from launching a second reconnect while the first
  // is still in flight (an MQTT connect can take several seconds on a busy LAN).
  final Set<String> _reconnectInFlight = <String>{};
  final AdapterDeviceInfoLogGate _deviceInfoLogGate =
      AdapterDeviceInfoLogGate();

  String _sendKeyTopic() =>
      '/remoteapp/tv/remote_service/$_mqttTopicClientSegment/actions/sendkey';

  String _authTopic() =>
      '/remoteapp/tv/ui_service/$_mqttTopicClientSegment/actions/authenticationcode';

  String _launchTopic() =>
      '/remoteapp/tv/ui_service/$_mqttTopicClientSegment/actions/launchapp';

  String _resolvedTextTopic() => _textTopic.isEmpty
      ? '/remoteapp/tv/ui_service/$_mqttTopicClientSegment/actions/textinput'
      : _textTopic;

  @override
  Future<void> connect({required String deviceId}) async {
    _emitConnectionState(deviceId, ConnectionState.connecting);
    try {
      await _ensureConnected(deviceId);
      if (!_authorizedDeviceIds.contains(deviceId)) {
        throw const PinRequiredException(
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
      _emitConnectionState(deviceId, ConnectionState.connected);
    } catch (error) {
      _emitConnectionState(deviceId, ConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<void> submitAuthenticationCode({
    required String deviceId,
    required String fourDigitPin,
  }) async {
    final client = await _connectedClientFor(deviceId);
    final cleaned = fourDigitPin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleaned)) {
      throw ArgumentError.value(
        fourDigitPin,
        'fourDigitPin',
        'Expected exactly 4 digits',
      );
    }
    // The TV-displayed PIN is forwarded verbatim. VIDAA MQTT does not expose
    // a synchronous reply on the auth topic, so we mark the device authorized
    // optimistically once the publish completes; an incorrect PIN surfaces
    // later as silent key drops, which the pairing UI handles via its
    // retry-PIN flow rather than a transport-level error here.
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
  Future<void> sendKey({
    required String deviceId,
    required String keyName,
  }) async {
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

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Expected non-empty text');
    }
    final client = await _clientFor(deviceId);
    final payload = jsonEncode(<String, String>{'text': cleaned});
    _publishString(client, _resolvedTextTopic(), payload);
    emitTransportEvent(
      TransportEvent(
        transport: 'hisense',
        deviceId: deviceId,
        type: 'text_sent',
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
      _startConnectivityPolling(deviceId);
      _emitConnectionState(deviceId, ConnectionState.connected);
      return;
    }
    existing?.disconnect();
    _deviceInfoLogGate.reset(deviceId);

    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError(
        'Hisense TV host could not be resolved for device $deviceId',
      );
    }

    final client =
        MqttServerClient.withPort(host, _mqttTopicClientSegment, _brokerPort)
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
      throw StateError(
        'Hisense MQTT connect failed (${status?.state}): $status',
      );
    }
    _mqttByDeviceId[deviceId] = client;
    _emitConnectionState(deviceId, ConnectionState.connected);
    _startConnectivityPolling(deviceId);
    if (_deviceInfoLogGate.shouldLog(deviceId)) {
      log(
        '[$deviceId] hisense transport connected: host=$host port=$_brokerPort '
        'tls=${!_usePlaintextMqtt} clientId=$_mqttTopicClientSegment',
        name: 'hisense_transport',
      );
    }
  }

  @override
  Future<void> probe(String host) async {
    try {
      final socket = await Socket.connect(
        host,
        _brokerPort,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
    } catch (_) {
      throw SocketException('$host unreachable on Hisense port $_brokerPort');
    }
  }

  void _publishString(MqttServerClient client, String topic, String body) {
    final builder = MqttClientPayloadBuilder()..addString(body);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _connectionControllerFor(deviceId).stream;

  StreamController<ConnectionState> _connectionControllerFor(String deviceId) {
    return _connectionControllers.putIfAbsent(
      deviceId,
      () => StreamController<ConnectionState>.broadcast(
        onListen: () {
          _connectionControllers[deviceId]?.add(
            _lastConnectionStates[deviceId] ?? ConnectionState.disconnected,
          );
        },
      ),
    );
  }

  void _emitConnectionState(String deviceId, ConnectionState state) {
    if (_lastConnectionStates[deviceId] == state) {
      return;
    }
    _lastConnectionStates[deviceId] = state;
    final ctrl = _connectionControllers[deviceId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(state);
    }
  }

  void _startConnectivityPolling(String deviceId) {
    _connectivityPollTimers[deviceId]?.cancel();
    _connectivityPollTimers[deviceId] = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_pollConnectivity(deviceId)),
    );
  }

  Future<void> _pollConnectivity(String deviceId) async {
    final client = _mqttByDeviceId[deviceId];
    final mqttConnected =
        client?.connectionStatus?.state == MqttConnectionState.connected;
    if (!mqttConnected) {
      _emitConnectionState(deviceId, ConnectionState.disconnected);
      await _maybeReconnect(deviceId);
      return;
    }
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      _emitConnectionState(deviceId, ConnectionState.error);
      return;
    }
    try {
      final socket = await Socket.connect(
        host,
        _brokerPort,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      _emitConnectionState(deviceId, ConnectionState.connected);
    } catch (_) {
      _emitConnectionState(deviceId, ConnectionState.disconnected);
      await _maybeReconnect(deviceId);
    }
  }

  /// Attempts a single, non-overlapping reconnect for devices that have
  /// already cleared the PIN gate in this session. Skipped when the device
  /// is not yet authorized, when a reconnect is already in flight, or when
  /// the host cannot be resolved — the lazy reconnect path on the next user
  /// action still covers those cases.
  Future<void> _maybeReconnect(String deviceId) async {
    if (!_authorizedDeviceIds.contains(deviceId)) return;
    if (_reconnectInFlight.contains(deviceId)) return;
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) return;
    _reconnectInFlight.add(deviceId);
    _emitConnectionState(deviceId, ConnectionState.connecting);
    try {
      await _ensureConnected(deviceId);
    } catch (_) {
      _emitConnectionState(deviceId, ConnectionState.disconnected);
    } finally {
      _reconnectInFlight.remove(deviceId);
    }
  }

  @override
  Future<void> clearPairing({required String deviceId}) async {
    _connectivityPollTimers.remove(deviceId)?.cancel();
    _authorizedDeviceIds.remove(deviceId);
    _reconnectInFlight.remove(deviceId);
    final client = _mqttByDeviceId.remove(deviceId);
    try {
      client?.disconnect();
    } catch (_) {
      // Ignore disconnect errors; the device is being removed regardless.
    }
    _deviceInfoLogGate.reset(deviceId);
    _emitConnectionState(deviceId, ConnectionState.disconnected);
  }
}
