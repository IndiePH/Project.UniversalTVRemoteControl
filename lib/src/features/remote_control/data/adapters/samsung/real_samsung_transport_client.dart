import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:one_remote/src/features/remote_control/data/adapters/samsung/samsung_transport_client.dart';

/// WebSocket transport scaffold for Samsung TVs.
///
/// Notes:
/// - This keeps protocol details isolated from UI/adapter routing.
/// - It currently assumes modern Samsung remote-control channel format.
/// - Device host lookup is delegated to [hostResolver] until repository models
///   carry explicit network endpoint metadata.
class RealSamsungTransportClient implements SamsungTransportClient {
  /// When true, logs outbound text-related frames and inbound socket messages
  /// (filter logcat by name `samsung_transport`).
  ///
  /// Enable for a build with:
  /// `--dart-define=SAMSUNG_TRANSPORT_DEBUG=true`
  static const bool _debugTransport = bool.fromEnvironment(
    'SAMSUNG_TRANSPORT_DEBUG',
    defaultValue: false,
  );

  RealSamsungTransportClient({
    required String Function(String deviceId) hostResolver,
    this.clientName = 'RemoteOne',
    this.connectTimeout = const Duration(seconds: 8),
    this.handshakeTimeout = const Duration(seconds: 30),
    this.keyDelay = const Duration(milliseconds: 200),
  }) : _hostResolver = hostResolver;

  final String Function(String deviceId) _hostResolver;
  final String clientName;
  final Duration connectTimeout;
  final Duration handshakeTimeout;
  final Duration keyDelay;
  final Map<String, WebSocket> _socketsByDeviceId = <String, WebSocket>{};
  final Map<String, StreamSubscription<dynamic>> _subscriptionsByDeviceId =
      <String, StreamSubscription<dynamic>>{};
  final Map<String, String> _tokenByHost = <String, String>{};
  final Map<String, DateTime> _lastSendAtByDeviceId = <String, DateTime>{};
  final Map<String, Set<Completer<void>>> _pendingPairingByHost =
      <String, Set<Completer<void>>>{};

  @override
  Future<void> connect({required String deviceId}) async {
    final existing = _socketsByDeviceId[deviceId];
    if (existing != null && existing.readyState == WebSocket.open) {
      return;
    }

    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Samsung host resolver returned an empty host.');
    }
    final secureToken = _tokenByHost[host];
    final encodedName = base64Encode(utf8.encode(clientName));

    final uriCandidates = <Uri>[
      // Prefer secure channel with known token when available.
      if (secureToken != null && secureToken.isNotEmpty)
        Uri.parse(
          'wss://$host:8002/api/v2/channels/samsung.remote.control'
          '?name=$encodedName&token=$secureToken',
        ),
      // Secure endpoint first so first-time pairing can receive auth token.
      Uri.parse(
        'wss://$host:8002/api/v2/channels/samsung.remote.control?name=$encodedName',
      ),
      // Common LAN WebSocket endpoint for local control.
      Uri.parse(
        'ws://$host:8001/api/v2/channels/samsung.remote.control?name=$encodedName',
      ),
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
        return;
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        await _resetConnection(deviceId);
        if (_isAuthorizationError(error)) {
          _tokenByHost.remove(host);
        }
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

    // Force an unauthenticated connection first so the TV can prompt approval.
    await _resetConnection(deviceId);
    await _connectWithoutToken(deviceId: deviceId, host: host);

    if ((_tokenByHost[host] ?? '').isEmpty) {
      final completer = Completer<void>();
      final pending = _pendingPairingByHost.putIfAbsent(
        host,
        () => <Completer<void>>{},
      );
      pending.add(completer);

      try {
        await sendKey(deviceId: deviceId, keyCode: triggerKeyCode);
        await completer.future.timeout(
          approvalTimeout,
          onTimeout: () => throw TimeoutException(
            'Timed out waiting for Samsung TV approval. Approve the TV popup and retry pairing.',
          ),
        );
      } finally {
        final current = _pendingPairingByHost[host];
        current?.remove(completer);
        if (current != null && current.isEmpty) {
          _pendingPairingByHost.remove(host);
        }
      }
    }

    // Pairing is only considered successful once token-authenticated connection
    // is usable. This avoids returning to home before TV approval is complete.
    while (DateTime.now().isBefore(deadline)) {
      try {
        await _resetConnection(deviceId);
        await _connectWithKnownToken(deviceId: deviceId, host: host);
        return;
      } on Object catch (error) {
        if (!_isAuthorizationError(error)) {
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
  }

  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {
    final socket = await _socketFor(deviceId);
    if (_debugTransport) {
      log(
        '[$deviceId] sendText: chars=${text.length} utf8Bytes=${utf8.encode(text).length}',
        name: 'samsung_transport',
      );
    }

    // Many Samsung sets ignore SendInputString until the TV is primed for IME
    // input (see samsung-tv-ws-api ChannelEmitCommand.text_received).
    await _applyKeyPacing(deviceId);
    final emitPayload = jsonEncode(<String, dynamic>{
      'method': 'ms.channel.emit',
      'params': <String, dynamic>{
        'event': 'custom.remote.textReceived',
        'to': 'broadcast',
      },
    });
    _logOutbound(deviceId, emitPayload);
    socket.add(emitPayload);
    _lastSendAtByDeviceId[deviceId] = DateTime.now();

    // SendInputString uses the same envelope as other remote commands, but the
    // base64 payload belongs in Cmd and DataOfCmd is the literal "base64"
    // (not the encoded bytes — this matches reference Samsung WS clients).
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
    _logOutbound(deviceId, inputPayload);
    socket.add(inputPayload);
    _lastSendAtByDeviceId[deviceId] = DateTime.now();

    await _applyKeyPacing(deviceId);
    final endPayload = jsonEncode(<String, dynamic>{
      'method': 'ms.remote.control',
      'params': <String, dynamic>{'TypeOfRemote': 'SendInputEnd'},
    });
    _logOutbound(deviceId, endPayload);
    socket.add(endPayload);
    _lastSendAtByDeviceId[deviceId] = DateTime.now();
  }

  Future<WebSocket> _openSocket(Uri uri) {
    if (uri.scheme == 'wss') {
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              // Samsung local-network certs are commonly self-signed.
              return true;
            };
      return WebSocket.connect(uri.toString(), customClient: client);
    }
    return WebSocket.connect(uri.toString());
  }

  Future<void> _connectWithoutToken({
    required String deviceId,
    required String host,
  }) async {
    final encodedName = base64Encode(utf8.encode(clientName));
    final uri = Uri.parse(
      'wss://$host:8002/api/v2/channels/samsung.remote.control?name=$encodedName',
    );
    final socket = await _openSocket(uri).timeout(connectTimeout);
    final handshakeCompleter = Completer<void>();
    _bindSocket(
      deviceId: deviceId,
      host: host,
      socket: socket,
      handshakeCompleter: handshakeCompleter,
    );
    await handshakeCompleter.future.timeout(handshakeTimeout);
  }

  Future<void> _connectWithKnownToken({
    required String deviceId,
    required String host,
  }) async {
    final token = _tokenByHost[host]?.trim() ?? '';
    if (token.isEmpty) {
      throw StateError('Samsung pairing token is not available yet.');
    }
    final encodedName = base64Encode(utf8.encode(clientName));
    final uri = Uri.parse(
      'wss://$host:8002/api/v2/channels/samsung.remote.control'
      '?name=$encodedName&token=$token',
    );
    final socket = await _openSocket(uri).timeout(connectTimeout);
    final handshakeCompleter = Completer<void>();
    _bindSocket(
      deviceId: deviceId,
      host: host,
      socket: socket,
      handshakeCompleter: handshakeCompleter,
    );
    await handshakeCompleter.future.timeout(handshakeTimeout);
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
    _subscriptionsByDeviceId[deviceId]?.cancel();
    _subscriptionsByDeviceId[deviceId] = socket.listen(
      (message) {
        if (message is! String) {
          return;
        }
        _logInbound(deviceId, message);
        _completeHandshakeIfReady(
          rawMessage: message,
          handshakeCompleter: handshakeCompleter,
        );
        _captureSamsungTokenIfPresent(
          deviceId: deviceId,
          host: host,
          rawMessage: message,
        );
      },
      onDone: () {
        if (handshakeCompleter != null && !handshakeCompleter.isCompleted) {
          handshakeCompleter.completeError(
            StateError('Samsung socket closed before handshake completed.'),
          );
        }
        _subscriptionsByDeviceId.remove(deviceId)?.cancel();
        _socketsByDeviceId.remove(deviceId);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (handshakeCompleter != null && !handshakeCompleter.isCompleted) {
          handshakeCompleter.completeError(error, stackTrace);
        }
        _subscriptionsByDeviceId.remove(deviceId)?.cancel();
        _socketsByDeviceId.remove(deviceId);
      },
      cancelOnError: false,
    );
  }

  void _completeHandshakeIfReady({
    required String rawMessage,
    required Completer<void>? handshakeCompleter,
  }) {
    if (handshakeCompleter == null || handshakeCompleter.isCompleted) {
      return;
    }
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final event = decoded['event'];
      if (event is! String) {
        return;
      }
      if (event == 'ms.channel.connect' || event == 'ms.channel.ready') {
        handshakeCompleter.complete();
        return;
      }
      if (event == 'ms.channel.unauthorized') {
        handshakeCompleter.completeError(
          _SamsungAuthorizationException(
            'Samsung TV rejected remote-control authorization.',
          ),
        );
        return;
      }

      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String &&
            message.toLowerCase().contains('unauthorized')) {
          handshakeCompleter.completeError(
            _SamsungAuthorizationException(
              'Samsung TV rejected remote-control authorization.',
            ),
          );
        }
      }
    } catch (_) {
      // Ignore non-JSON messages and keep waiting for handshake frame.
    }
  }

  void _captureSamsungTokenIfPresent({
    required String deviceId,
    required String host,
    required String rawMessage,
  }) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      if (_isUnauthorizedFrame(decoded)) {
        _failPendingPairingApprovals(
          host: host,
          error: _SamsungAuthorizationException(
            'Samsung TV rejected remote-control authorization.',
          ),
        );
        unawaited(_resetConnection(deviceId));
        return;
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return;
      }
      final token = data['token'];
      if (token is String && token.trim().isNotEmpty) {
        _tokenByHost[host] = token.trim();
        _completePendingPairingApprovals(host);
      }
    } catch (_) {
      // Some frames are non-JSON/heartbeat payloads.
    }
  }

  bool _isUnauthorizedFrame(Map<String, dynamic> decoded) {
    final event = decoded['event'];
    if (event is String && event == 'ms.channel.unauthorized') {
      return true;
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.toLowerCase().contains('unauthorized')) {
        return true;
      }
    }
    return false;
  }

  void _completePendingPairingApprovals(String host) {
    final pending = _pendingPairingByHost.remove(host);
    if (pending == null) {
      return;
    }
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  void _failPendingPairingApprovals({
    required String host,
    required Object error,
  }) {
    final pending = _pendingPairingByHost.remove(host);
    if (pending == null) {
      return;
    }
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
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

  bool _isAuthorizationError(Object error) {
    if (error is _SamsungAuthorizationException) {
      return true;
    }
    return error.toString().toLowerCase().contains('authorization');
  }

  void _logOutbound(String deviceId, String payload) {
    if (!_debugTransport) {
      return;
    }
    log(
      '[$deviceId] TX: ${_summarizeOutboundPayload(payload)}',
      name: 'samsung_transport',
    );
  }

  void _logInbound(String deviceId, String rawMessage) {
    if (!_debugTransport) {
      return;
    }
    log(
      '[$deviceId] RX: ${_summarizeInboundMessage(rawMessage)}',
      name: 'samsung_transport',
    );
  }

  String _summarizeOutboundPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return _truncate(payload, 500);
      }
      final method = decoded['method'];
      final params = decoded['params'];
      if (params is Map<String, dynamic>) {
        final type = params['TypeOfRemote'];
        if (type == 'SendInputString' && params['Cmd'] is String) {
          final cmd = params['Cmd'] as String;
          final preview = cmd.length > 56 ? '${cmd.substring(0, 56)}...' : cmd;
          return 'method=$method SendInputString cmdLen=${cmd.length} cmdPreview=$preview';
        }
        if (type == 'SendInputEnd') {
          return 'method=$method SendInputEnd';
        }
      }
      if (method == 'ms.channel.emit') {
        return 'method=$method params=${_truncate(jsonEncode(params), 280)}';
      }
      return _truncate(payload, 500);
    } catch (_) {
      return _truncate(payload, 500);
    }
  }

  String _summarizeInboundMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '(empty)';
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return _truncate(trimmed, 500);
      }
      final event = decoded['event'];
      final method = decoded['method'];
      final data = decoded['data'];
      final error = decoded['error'];
      final buffer = StringBuffer();
      if (event != null) {
        buffer.write('event=$event ');
      }
      if (method != null) {
        buffer.write('method=$method ');
      }
      if (error != null) {
        buffer.write('error=$error ');
      }
      if (data is Map<String, dynamic>) {
        final msg = data['message'];
        if (msg != null) {
          buffer.write('data.message=$msg ');
        }
        final token = data['token'];
        if (token is String && token.isNotEmpty) {
          buffer.write('data.token(len)=${token.length} ');
        }
        buffer.write('data.keys=${data.keys.take(12).join(',')}');
      }
      final out = buffer.toString().trim();
      return out.isEmpty ? _truncate(trimmed, 500) : out;
    } catch (_) {
      return _truncate(trimmed, 500);
    }
  }

  String _truncate(String value, int max) {
    if (value.length <= max) {
      return value;
    }
    return '${value.substring(0, max)}...';
  }

  Future<void> _resetConnection(String deviceId) async {
    await _subscriptionsByDeviceId.remove(deviceId)?.cancel();
    final socket = _socketsByDeviceId.remove(deviceId);
    _lastSendAtByDeviceId.remove(deviceId);
    if (socket == null) {
      return;
    }
    try {
      await socket.close();
    } catch (_) {
      // Ignore close failures for broken sockets.
    }
  }
}

final class _SamsungAuthorizationException implements Exception {
  const _SamsungAuthorizationException(this.message);

  final String message;

  @override
  String toString() => message;
}
