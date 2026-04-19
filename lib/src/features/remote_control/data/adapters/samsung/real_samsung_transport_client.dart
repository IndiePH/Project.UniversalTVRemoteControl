import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:one_remote/src/features/remote_control/application/text_input_compatibility_exception.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/samsung_transport_file_logger.dart';
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
    defaultValue: true,
  );
  static const bool _sendInputEndAfterEachText = bool.fromEnvironment(
    'SAMSUNG_SEND_INPUT_END_PER_TEXT',
    defaultValue: false,
  );

  RealSamsungTransportClient({
    required String Function(String deviceId) hostResolver,
    this.clientName = 'OneRemote',
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
  final Map<String, bool> _isImeActiveByDeviceId = <String, bool>{};
  final Map<String, bool> _isImeSessionPrimedByDeviceId = <String, bool>{};
  final Map<String, String> _appContextByDeviceId = <String, String>{};
  final SamsungTransportFileLogger _fileLogger = SamsungTransportFileLogger();

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
      _logDebug(
        '[$deviceId] sendText: chars=${text.length} utf8Bytes=${utf8.encode(text).length}',
      );
    }

    // Many Samsung sets require IME priming (`custom.remote.textReceived`)
    // before accepting SendInputString frames. Prime once per IME session.
    await _waitForImeState(
      deviceId,
      timeout: const Duration(milliseconds: 500),
    );
    await _primeImeSession(deviceId: deviceId, socket: socket);
    await _waitForImeState(
      deviceId,
      timeout: const Duration(milliseconds: 600),
    );
    if (!(_isImeActiveByDeviceId[deviceId] ?? false)) {
      final appContext = _appContextByDeviceId[deviceId];
      final buffer = StringBuffer(
        'Typing from this phone is not available on this TV screen or app. ',
      )
        ..write(
          'Use the TV on-screen keyboard and direction buttons to enter text.',
        );
      if (appContext != null && appContext.isNotEmpty) {
        buffer.write(' (TV reports app context: $appContext)');
      }
      throw TextInputCompatibilityException(buffer.toString());
    }

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

    // Some models behave better when SendInputEnd is not sent immediately
    // after every text payload. Keep it opt-in for diagnostics/fallback.
    if (_sendInputEndAfterEachText) {
      await _sendInputEnd(deviceId: deviceId, socket: socket);
    }
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
    _isImeActiveByDeviceId[deviceId] = false;
    _isImeSessionPrimedByDeviceId[deviceId] = false;
    _subscriptionsByDeviceId[deviceId]?.cancel();
    _subscriptionsByDeviceId[deviceId] = socket.listen(
      (message) {
        if (message is! String) {
          return;
        }
        _captureAppContext(deviceId: deviceId, rawMessage: message);
        _captureImeSessionState(deviceId: deviceId, rawMessage: message);
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
        _isImeActiveByDeviceId.remove(deviceId);
        _isImeSessionPrimedByDeviceId.remove(deviceId);
        _appContextByDeviceId.remove(deviceId);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (handshakeCompleter != null && !handshakeCompleter.isCompleted) {
          handshakeCompleter.completeError(error, stackTrace);
        }
        _subscriptionsByDeviceId.remove(deviceId)?.cancel();
        _socketsByDeviceId.remove(deviceId);
        _isImeActiveByDeviceId.remove(deviceId);
        _isImeSessionPrimedByDeviceId.remove(deviceId);
        _appContextByDeviceId.remove(deviceId);
      },
      cancelOnError: false,
    );
  }

  Future<void> _primeImeSession({
    required String deviceId,
    required WebSocket socket,
  }) async {
    if (_isImeSessionPrimedByDeviceId[deviceId] ?? false) {
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
    _logOutbound(deviceId, emitPayload);
    socket.add(emitPayload);
    _lastSendAtByDeviceId[deviceId] = DateTime.now();
    _isImeSessionPrimedByDeviceId[deviceId] = true;
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
    _logOutbound(deviceId, endPayload);
    socket.add(endPayload);
    _lastSendAtByDeviceId[deviceId] = DateTime.now();
  }

  Future<void> _waitForImeState(
    String deviceId, {
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_isImeActiveByDeviceId[deviceId] ?? false) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  void _captureAppContext({
    required String deviceId,
    required String rawMessage,
  }) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final method = decoded['method'];
      if (method is String && method.isNotEmpty) {
        _appContextByDeviceId[deviceId] = 'method=$method';
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return;
      }
      final appId = data['appId'] ?? data['id'];
      if (appId is String && appId.trim().isNotEmpty) {
        final trimmed = appId.trim();
        final event = decoded['event'];
        if (event is String && event.isNotEmpty) {
          _appContextByDeviceId[deviceId] = 'event=$event appId=$trimmed';
        } else {
          _appContextByDeviceId[deviceId] = 'appId=$trimmed';
        }
      }
    } catch (_) {
      // Ignore non-JSON frames when tracking app context.
    }
  }

  void _captureImeSessionState({
    required String deviceId,
    required String rawMessage,
  }) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final event = decoded['event'];
      if (event is! String) {
        return;
      }
      final eventLower = event.toLowerCase();
      if (!eventLower.contains('ime')) {
        return;
      }
      if (eventLower.contains('start')) {
        _isImeActiveByDeviceId[deviceId] = true;
        _isImeSessionPrimedByDeviceId[deviceId] = false;
        if (_debugTransport) {
          _logDebug('[$deviceId] RX: IME start');
        }
        return;
      }
      if (eventLower.contains('end')) {
        _isImeActiveByDeviceId[deviceId] = false;
        _isImeSessionPrimedByDeviceId[deviceId] = false;
        if (_debugTransport) {
          _logDebug('[$deviceId] RX: IME end');
        }
      }
    } catch (_) {
      // Ignore non-JSON frames when tracking IME session state.
    }
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
    _logDebug('[$deviceId] TX: ${_summarizeOutboundPayload(payload)}');
  }

  void _logDebug(String message) {
    log(message, name: 'samsung_transport');
    _fileLogger.write(message);
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
    _isImeActiveByDeviceId.remove(deviceId);
    _isImeSessionPrimedByDeviceId.remove(deviceId);
    _appContextByDeviceId.remove(deviceId);
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
