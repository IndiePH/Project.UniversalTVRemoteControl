import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/data/adapters/adapter_device_info_log_gate.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_pairing_token_store.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_remote_text_session.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_logging.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_ws_handshake.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_tls_trust_store.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_app_launch.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_authorization.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_client.dart';

/// WebSocket transport scaffold for Samsung TVs.
///
/// Notes:
/// - This keeps protocol details isolated from UI/adapter routing.
/// - It currently assumes modern Samsung remote-control channel format.
/// - Device host lookup is delegated to [hostResolver] until repository models
///   carry explicit network endpoint metadata.
///
/// Implementation is split across focused types: [SamsungPairingTokenStore],
/// [SamsungRemoteTextSession], [SamsungTransportLogging], and
/// [SamsungWsHandshake].
class SamsungWebSocketTransportClient
    with TransportEventEmitterMixin
    implements SamsungTransportClient {
  static const int _tlsPort = 8002;
  static const int _plainPort = 8001;
  static const String _channelPath = '/api/v2/channels/samsung.remote.control';

  static const bool _sendInputEndAfterEachText = bool.fromEnvironment(
    'SAMSUNG_SEND_INPUT_END_PER_TEXT',
    defaultValue: false,
  );

  SamsungWebSocketTransportClient({
    required String Function(String deviceId) hostResolver,
    this.clientName = 'OneRemote',
    this.connectTimeout = const Duration(seconds: 8),
    this.handshakeTimeout = const Duration(seconds: 30),
    this.keyDelay = const Duration(milliseconds: 200),
    SamsungTransportLogging? transportLogging,
    SamsungPairingTokenStore? pairingTokenStore,
    SamsungRemoteTextSession? remoteTextSession,
  }) : _hostResolver = hostResolver,
       _logging = transportLogging ?? SamsungTransportLogging(),
       _pairing = pairingTokenStore ?? SamsungPairingTokenStore(),
       _text = remoteTextSession ?? SamsungRemoteTextSession();

  final String Function(String deviceId) _hostResolver;
  final String clientName;
  final Duration connectTimeout;
  final Duration handshakeTimeout;
  final Duration keyDelay;
  final SamsungTransportLogging _logging;
  final SamsungPairingTokenStore _pairing;
  final SamsungRemoteTextSession _text;

  final Map<String, WebSocket> _socketsByDeviceId = <String, WebSocket>{};
  final Map<String, StreamSubscription<dynamic>> _subscriptionsByDeviceId =
      <String, StreamSubscription<dynamic>>{};
  final Map<String, DateTime> _lastSendAtByDeviceId = <String, DateTime>{};
  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      <String, StreamController<ConnectionState>>{};
  final Map<String, ConnectionState> _lastConnectionStates =
      <String, ConnectionState>{};
  final AdapterDeviceInfoLogGate _deviceInfoLogGate =
      AdapterDeviceInfoLogGate();

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) {
    return _text.watchRemoteTextInputReady(deviceId);
  }

  @override
  Future<bool> probeRemoteTextInputReady({
    required String deviceId,
    Duration timeout = const Duration(milliseconds: 750),
  }) async {
    await connect(deviceId: deviceId);
    if (_text.isImeActive(deviceId)) {
      return true;
    }
    final socket = await _socketFor(deviceId);
    await _primeImeSession(deviceId: deviceId, socket: socket);
    await _waitForImeState(deviceId, timeout: timeout);
    return _text.isImeActive(deviceId);
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _connectionControllerFor(deviceId).stream;

  @override
  Future<void> connect({required String deviceId}) async {
    final existing = _socketsByDeviceId[deviceId];
    if (existing != null && existing.readyState == WebSocket.open) {
      _emitConnectionState(deviceId, ConnectionState.connected);
      return;
    }

    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Samsung host resolver returned an empty host.');
    }
    final secureToken = _pairing.tokenForHost(host);
    final encodedName = base64Encode(utf8.encode(clientName));
    _emitConnectionState(deviceId, ConnectionState.connecting);

    final uriCandidates = <Uri>[
      if (secureToken != null && secureToken.isNotEmpty)
        Uri.parse(
          'wss://$host:$_tlsPort$_channelPath'
          '?name=$encodedName&token=$secureToken',
        ),
      Uri.parse('wss://$host:$_tlsPort$_channelPath?name=$encodedName'),
      Uri.parse('ws://$host:$_plainPort$_channelPath?name=$encodedName'),
    ];

    Object? lastError;
    StackTrace? lastStackTrace;
    for (final uri in uriCandidates) {
      try {
        final socket = await _openSocket(uri).timeout(connectTimeout);
        final handshakeCompleter = Completer<void>();
        _bindSocket(
          deviceId: deviceId,
          host: host,
          socket: socket,
          handshakeCompleter: handshakeCompleter,
        );
        await handshakeCompleter.future.timeout(handshakeTimeout);
        if (uri.scheme == 'wss') {
          SamsungTlsTrustStore.instance.commitPendingPins(
            host: host,
            port: uri.port,
          );
        }
        emitTransportEvent(
          TransportEvent(
            transport: 'samsung',
            deviceId: deviceId,
            type: 'connected',
            message: '$host:${uri.port}',
          ),
        );
        _emitConnectionState(deviceId, ConnectionState.connected);
        return;
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (uri.scheme == 'wss') {
          SamsungTlsTrustStore.instance.abandonPendingPins(
            host: host,
            port: uri.port,
          );
        }
        await _resetConnection(deviceId);
        if (SamsungTransportAuthorization.isAuthorizationError(error)) {
          _pairing.clearTokenForHost(host);
        }
        _emitConnectionState(deviceId, ConnectionState.error);
      }
    }

    throw StateError(
      'Failed to connect to Samsung TV at $host. Last error: $lastError'
      '${lastStackTrace == null ? '' : '\n$lastStackTrace'}',
    );
  }

  @override
  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  }) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Samsung host resolver returned an empty host.');
    }
    final deadline = DateTime.now().add(approvalTimeout);

    await SamsungTlsTrustStore.instance.ensureLoaded();
    final hasStoredToken = _pairing.hasNonEmptyToken(host);
    if (!hasStoredToken) {
      await SamsungTlsTrustStore.instance.clearEndpoint(host, _tlsPort);
    }
    emitTransportEvent(
      TransportEvent(
        transport: 'samsung',
        deviceId: deviceId,
        type: 'pairing_approval_requested',
      ),
    );

    await _resetConnection(deviceId);

    if (!hasStoredToken) {
      await _connectWith(deviceId: deviceId, host: host);

      final completer = Completer<void>();
      _pairing.registerPendingApproval(host, completer);

      try {
        if (_pairing.trimmedTokenForHost(host).isEmpty) {
          await sendKey(deviceId: deviceId, keyCode: triggerKeyCode);
          await completer.future.timeout(
            approvalTimeout,
            onTimeout: () => throw TimeoutException(
              'Timed out waiting for Samsung TV approval. Approve the TV popup and retry pairing.',
            ),
          );
        }
      } finally {
        _pairing.unregisterPendingApproval(host, completer);
      }
    }

    while (DateTime.now().isBefore(deadline)) {
      try {
        await _resetConnection(deviceId);
        final token = _pairing.trimmedTokenForHost(host);
        if (token.isEmpty) {
          throw StateError('Samsung pairing token is not available yet.');
        }
        await _connectWith(deviceId: deviceId, host: host, token: token);
        return;
      } on Object catch (error) {
        if (!SamsungTransportAuthorization.isAuthorizationError(error)) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }

    throw TimeoutException(
      'Timed out waiting for Samsung TV approval. Approve the TV popup and retry pairing.',
    );
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    if (keyCode.startsWith(samsungLaunchPrefix)) {
      final appId = keyCode.substring(samsungLaunchPrefix.length);
      await launchApp(deviceId: deviceId, appId: appId);
      return;
    }

    final socket = await _socketFor(deviceId);
    await _applyKeyPacing(deviceId);

    final payload = <String, dynamic>{
      'method': 'ms.remote.control',
      'params': <String, dynamic>{
        'Cmd': 'Click',
        'DataOfCmd': keyCode,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    };
    socket.add(jsonEncode(payload));
    _lastSendAtByDeviceId[deviceId] = DateTime.now();
    emitTransportEvent(
      TransportEvent(
        transport: 'samsung',
        deviceId: deviceId,
        type: 'key_sent',
        message: keyCode,
      ),
    );
  }

  /// Launches a Tizen app via `ms.channel.emit` / `ed.apps.launch`.
  Future<void> launchApp({
    required String deviceId,
    required String appId,
    String actionType = 'NATIVE_LAUNCH',
  }) async {
    final socket = await _socketFor(deviceId);
    await _applyKeyPacing(deviceId);

    final payload = jsonEncode(<String, dynamic>{
      'method': 'ms.channel.emit',
      'params': <String, dynamic>{
        'event': 'ed.apps.launch',
        'to': 'host',
        'data': <String, dynamic>{'appId': appId, 'action_type': actionType},
      },
    });
    _logging.logOutbound(deviceId, payload);
    socket.add(payload);
    _lastSendAtByDeviceId[deviceId] = DateTime.now();
    emitTransportEvent(
      TransportEvent(
        transport: 'samsung',
        deviceId: deviceId,
        type: 'app_launched',
        message: appId,
      ),
    );
  }

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {
    final socket = await _socketFor(deviceId);
    if (_logging.enabled) {
      _logging.logDebug(
        '[$deviceId] sendText: chars=${text.length} utf8Bytes=${utf8.encode(text).length}',
      );
    }

    await _waitForImeState(
      deviceId,
      timeout: const Duration(milliseconds: 500),
    );
    await _primeImeSession(deviceId: deviceId, socket: socket);
    await _waitForImeState(
      deviceId,
      timeout: const Duration(milliseconds: 600),
    );
    _text.ensureImeActiveForSendText(deviceId);

    final encodedText = base64Encode(utf8.encode(text));
    await _applyKeyPacing(deviceId);
    final inputPayload = jsonEncode(<String, dynamic>{
      'method': 'ms.remote.control',
      'params': <String, dynamic>{
        'Cmd': encodedText,
        'DataOfCmd': 'base64',
        'TypeOfRemote': 'SendInputString',
      },
    });
    _logging.logOutbound(deviceId, inputPayload);
    socket.add(inputPayload);
    _lastSendAtByDeviceId[deviceId] = DateTime.now();
    emitTransportEvent(
      TransportEvent(
        transport: 'samsung',
        deviceId: deviceId,
        type: 'text_sent',
      ),
    );

    if (_sendInputEndAfterEachText) {
      await _sendInputEnd(deviceId: deviceId, socket: socket);
    }
  }

  Future<WebSocket> _openSocket(Uri uri) async {
    if (uri.scheme == 'wss') {
      await SamsungTlsTrustStore.instance.ensureLoaded();
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              return SamsungTlsTrustStore.instance.verifyServerCertificate(
                host: host,
                port: port,
                cert: cert,
              );
            };
      return WebSocket.connect(uri.toString(), customClient: client);
    }
    return WebSocket.connect(uri.toString());
  }

  Future<void> _connectWith({
    required String deviceId,
    required String host,
    String? token,
  }) async {
    final encodedName = base64Encode(utf8.encode(clientName));
    final uri = Uri.parse(
      token != null
          ? 'wss://$host:$_tlsPort$_channelPath?name=$encodedName&token=$token'
          : 'wss://$host:$_tlsPort$_channelPath?name=$encodedName',
    );
    try {
      final socket = await _openSocket(uri).timeout(connectTimeout);
      final handshakeCompleter = Completer<void>();
      _bindSocket(
        deviceId: deviceId,
        host: host,
        socket: socket,
        handshakeCompleter: handshakeCompleter,
      );
      await handshakeCompleter.future.timeout(handshakeTimeout);
      SamsungTlsTrustStore.instance.commitPendingPins(
        host: host,
        port: uri.port,
      );
    } on Object {
      SamsungTlsTrustStore.instance.abandonPendingPins(
        host: host,
        port: uri.port,
      );
      rethrow;
    }
  }

  Future<WebSocket> _socketFor(String deviceId) async {
    await connect(deviceId: deviceId);
    final socket = _socketsByDeviceId[deviceId];
    if (socket == null || socket.readyState != WebSocket.open) {
      throw StateError('Samsung socket is not connected for device: $deviceId');
    }
    return socket;
  }

  void _bindSocket({
    required String deviceId,
    required String host,
    required WebSocket socket,
    Completer<void>? handshakeCompleter,
  }) {
    _socketsByDeviceId[deviceId] = socket;
    _text.onSocketBound(deviceId);
    _subscriptionsByDeviceId[deviceId]?.cancel();
    _subscriptionsByDeviceId[deviceId] = socket.listen(
      (message) {
        if (message is! String) {
          return;
        }
        final decoded = _tryDecodeMessage(message);
        _logSamsungDeviceInfo(deviceId, decoded);
        _text.ingestDecoded(
          deviceId,
          decoded,
          onImeDebugLog: _logging.enabled ? _logging.logDebug : null,
        );
        SamsungWsHandshake.tryComplete(
          decoded: decoded,
          handshakeCompleter: handshakeCompleter,
        );
        final pairingOutcome = _pairing.handleDecoded(host, decoded);
        if (pairingOutcome == SamsungPairingFrameOutcome.unauthorized) {
          unawaited(_resetConnection(deviceId));
        }
      },
      onDone: () {
        if (handshakeCompleter != null && !handshakeCompleter.isCompleted) {
          handshakeCompleter.completeError(
            StateError('Samsung socket closed before handshake completed.'),
          );
        }
        _subscriptionsByDeviceId.remove(deviceId)?.cancel();
        _socketsByDeviceId.remove(deviceId);
        _text.onSocketLost(deviceId);
        emitTransportEvent(
          TransportEvent(
            transport: 'samsung',
            deviceId: deviceId,
            type: 'connection_closed',
          ),
        );
        _emitConnectionState(deviceId, ConnectionState.disconnected);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (handshakeCompleter != null && !handshakeCompleter.isCompleted) {
          handshakeCompleter.completeError(error, stackTrace);
        }
        _subscriptionsByDeviceId.remove(deviceId)?.cancel();
        _socketsByDeviceId.remove(deviceId);
        _text.onSocketLost(deviceId);
        emitTransportEvent(
          TransportEvent(
            transport: 'samsung',
            deviceId: deviceId,
            type: 'connection_error',
            message: error.toString(),
          ),
        );
        _emitConnectionState(deviceId, ConnectionState.error);
      },
      cancelOnError: false,
    );
  }

  Future<void> _primeImeSession({
    required String deviceId,
    required WebSocket socket,
  }) async {
    if (_text.isImeSessionPrimed(deviceId)) {
      return;
    }
    await _applyKeyPacing(deviceId);
    final emitPayload = jsonEncode(<String, dynamic>{
      'method': 'ms.channel.emit',
      'params': <String, dynamic>{
        'event': 'custom.remote.textReceived',
        'to': 'broadcast',
      },
    });
    _logging.logOutbound(deviceId, emitPayload);
    socket.add(emitPayload);
    _lastSendAtByDeviceId[deviceId] = DateTime.now();
    _text.markImeSessionPrimed(deviceId);
  }

  Future<void> _sendInputEnd({
    required String deviceId,
    required WebSocket socket,
  }) async {
    await _applyKeyPacing(deviceId);
    final endPayload = jsonEncode(<String, dynamic>{
      'method': 'ms.remote.control',
      'params': <String, dynamic>{'TypeOfRemote': 'SendInputEnd'},
    });
    _logging.logOutbound(deviceId, endPayload);
    socket.add(endPayload);
    _lastSendAtByDeviceId[deviceId] = DateTime.now();
  }

  Future<void> _waitForImeState(
    String deviceId, {
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_text.isImeActive(deviceId)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Map<String, dynamic>? _tryDecodeMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore non-JSON frames.
    }
    return null;
  }

  void _logSamsungDeviceInfo(String deviceId, Map<String, dynamic>? decoded) {
    if (!_logging.enabled || decoded == null) {
      return;
    }
    if (!_deviceInfoLogGate.shouldLog(deviceId)) {
      return;
    }

    final event = decoded['event'];
    if (event is! String || event != 'ms.channel.connect') {
      return;
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return;
    }

    final model = data['model']?.toString().trim();
    final os = data['OS']?.toString().trim();
    final firmware = data['firmwareVersion']?.toString().trim();
    final frameVersion = data['version']?.toString().trim();
    final id = data['id']?.toString().trim();

    final hasInfo = <String?>[
      model,
      os,
      firmware,
      frameVersion,
      id,
    ].any((value) => value != null && value.isNotEmpty);
    if (!hasInfo) {
      return;
    }

    _logging.logDebug(
      '[$deviceId] samsung device info: '
      'model=${model ?? "unknown"} '
      'os=${os ?? "unknown"} '
      'firmware=${firmware ?? "unknown"} '
      'frameVersion=${frameVersion ?? "unknown"} '
      'id=${id ?? "unknown"}',
    );
  }

  Future<void> _applyKeyPacing(String deviceId) async {
    final lastSentAt = _lastSendAtByDeviceId[deviceId];
    if (lastSentAt == null) {
      return;
    }
    final elapsed = DateTime.now().difference(lastSentAt);
    if (elapsed >= keyDelay) {
      return;
    }
    await Future<void>.delayed(keyDelay - elapsed);
  }

  /// Fails any pending TV-approval waiter and resets the connection.
  @override
  void cancelPairing(String deviceId) {
    final host = _hostResolver(deviceId).trim();
    _pairing.cancelPendingApprovals(host);
    unawaited(_resetConnection(deviceId));
  }

  @override
  Future<void> probe(String host) async {
    for (final port in const [_tlsPort, _plainPort]) {
      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 3),
        );
        socket.destroy();
        return;
      } catch (_) {}
    }
    throw SocketException('$host unreachable on Samsung ports');
  }

  Future<void> _resetConnection(String deviceId) async {
    await _subscriptionsByDeviceId.remove(deviceId)?.cancel();
    final socket = _socketsByDeviceId.remove(deviceId);
    _lastSendAtByDeviceId.remove(deviceId);
    _deviceInfoLogGate.reset(deviceId);
    _text.onSocketLost(deviceId);
    if (socket == null) {
      return;
    }
    try {
      await socket.close();
    } catch (_) {
      // Ignore close failures for broken sockets.
    }
    _emitConnectionState(deviceId, ConnectionState.disconnected);
  }

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
}
