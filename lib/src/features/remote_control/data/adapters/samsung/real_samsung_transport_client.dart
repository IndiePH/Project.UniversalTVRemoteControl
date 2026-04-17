import 'dart:async';
import 'dart:convert';
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

  @override
  Future<void> connect({
    required String deviceId,
  }) async {
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
      // Common LAN WebSocket endpoint for local control.
      Uri.parse(
        'ws://$host:8001/api/v2/channels/samsung.remote.control?name=$encodedName',
      ),
      // Secure endpoint fallback; token may be provided by connect events.
      Uri.parse(
        'wss://$host:8002/api/v2/channels/samsung.remote.control?name=$encodedName',
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
    await _applyKeyPacing(deviceId);

    final encodedText = base64Encode(utf8.encode(text));
    final payload = <String, dynamic>{
      'method': 'ms.remote.control',
      'params': <String, dynamic>{
        'Cmd': 'Click',
        'DataOfCmd': encodedText,
        'Option': 'false',
        'TypeOfRemote': 'SendInputString',
      },
    };
    socket.add(jsonEncode(payload));
    _lastSendAtByDeviceId[deviceId] = DateTime.now();
  }

  Future<WebSocket> _openSocket(Uri uri) {
    if (uri.scheme == 'wss') {
      final client = HttpClient()
        ..badCertificateCallback = (
          X509Certificate cert,
          String host,
          int port,
        ) {
          // Samsung local-network certs are commonly self-signed.
          return true;
        };
      return WebSocket.connect(uri.toString(), customClient: client);
    }
    return WebSocket.connect(uri.toString());
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
        _completeHandshakeIfReady(
          rawMessage: message,
          handshakeCompleter: handshakeCompleter,
        );
        _captureSamsungTokenIfPresent(host: host, rawMessage: message);
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
    required String host,
    required String rawMessage,
  }) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return;
      }
      final token = data['token'];
      if (token is String && token.trim().isNotEmpty) {
        _tokenByHost[host] = token.trim();
      }
    } catch (_) {
      // Some frames are non-JSON/heartbeat payloads.
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
