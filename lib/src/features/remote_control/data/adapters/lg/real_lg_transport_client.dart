import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:one_remote/src/features/remote_control/data/adapters/adapter_device_info_log_gate.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg/lg_exceptions.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg/lg_key_mapper.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg/lg_message_builder.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/lg/lg_transport_client.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/transport_event_emitter_mixin.dart';

/// Real WebSocket transport for LG webOS TVs using the SSAP protocol.
///
/// Connection flow:
///   1. Tries wss://host:3001 (webOS 22+), falls back to ws://host:3000 (webOS 2–6).
///   2. Sends the 39-permission registration manifest immediately after connecting.
///   3. For first-time pairing: TV shows on-screen prompt; [requestClientKey] waits
///      for the user to approve and returns the issued client-key.
///   4. For reconnection with a stored key: manifest includes the key, TV registers
///      silently, [watchRegistrationState] emits [LgRegistrationState.registered].
///
/// Dpad and back commands route via a separate pointer input socket obtained from
/// the TV. If the pointer socket is unavailable (webOS 2.x firmware), those
/// commands degrade gracefully with a logged warning rather than throwing.
class RealLgTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  RealLgTransportClient({
    required String Function(String deviceId) hostResolver,
    this.connectTimeout = const Duration(seconds: 8),
  }) : _hostResolver = hostResolver;

  final String Function(String deviceId) _hostResolver;
  final Duration connectTimeout;

  final Map<String, WebSocket> _sockets = {};
  final Map<String, StreamSubscription<dynamic>> _subs = {};
  final Map<String, WebSocket> _pointerSockets = {};
  final Map<String, StreamSubscription<dynamic>> _pointerSubs = {};

  // Resolved by the message handler when the TV issues a client-key.
  final Map<String, Completer<String>> _pairingCompleters = {};

  // Resolved by the message handler when a specific request ID gets a response.
  final Map<String, Completer<Map<String, dynamic>?>> _pendingRequests = {};

  final Map<String, StreamController<LgRegistrationState>> _registrationControllers = {};

  // Per-device mute state tracked in memory since SSAP setMute requires the target value.
  final Map<String, bool> _muteStates = {};

  final AdapterDeviceInfoLogGate _logGate = AdapterDeviceInfoLogGate();
  int _reqCounter = 0;

  @override
  Future<void> connect({required String deviceId}) async {
    final existing = _sockets[deviceId];
    if (existing != null && existing.readyState == WebSocket.open) return;

    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) throw StateError('LG host resolver returned empty host.');

    _emitRegistrationState(deviceId, LgRegistrationState.connecting);

    final uris = [
      Uri.parse('wss://$host:3001'),
      Uri.parse('ws://$host:3000'),
    ];

    Object? lastError;
    for (final uri in uris) {
      try {
        final socket = await _openSocket(uri).timeout(connectTimeout);
        _bindSocket(deviceId: deviceId, socket: socket);
        socket.add(jsonEncode(buildLgRegisterPayload()));
        emitTransportEvent(TransportEvent(
          transport: 'lg',
          deviceId: deviceId,
          type: 'connected',
          message: '$host:${uri.port}',
        ));
        return;
      } on Object catch (e) {
        lastError = e;
        await _resetConnection(deviceId);
      }
    }

    _emitRegistrationState(deviceId, LgRegistrationState.failed);
    throw StateError('Failed to connect to LG TV at $host. Last error: $lastError');
  }

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final completer = Completer<String>();
    _pairingCompleters[deviceId] = completer;
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw LgPairingTimeoutException(
          'Timed out waiting for LG TV pairing approval. '
          'Approve the on-screen prompt and retry.',
        ),
      );
    } finally {
      _pairingCompleters.remove(deviceId);
    }
  }

  @override
  Future<void> sendKey({required String deviceId, required String keyCode}) async {
    if (keyCode.startsWith(lgPointerPrefix)) {
      await _sendPointerCommand(
        deviceId: deviceId,
        button: keyCode.substring(lgPointerPrefix.length),
      );
    } else if (keyCode.startsWith(lgLaunchPrefix)) {
      final appId = keyCode.substring(lgLaunchPrefix.length);
      await _sendSsap(
        deviceId: deviceId,
        uri: 'ssap://com.webos.appmanager/launch',
        payload: {'id': appId},
      );
    } else if (keyCode == 'ssap://audio/setMute') {
      final newMute = !(_muteStates[deviceId] ?? false);
      _muteStates[deviceId] = newMute;
      await _sendSsap(deviceId: deviceId, uri: keyCode, payload: {'mute': newMute});
    } else {
      await _sendSsap(deviceId: deviceId, uri: keyCode, payload: const {});
    }
  }

  @override
  Future<void> sendText({required String deviceId, required String text}) async {
    await _sendSsap(
      deviceId: deviceId,
      uri: 'ssap://com.webos.service.ime/insertText',
      payload: {'text': text, 'replace': 0},
    );
  }

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      _registrationControllerFor(deviceId).stream;

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) => Stream<bool>.value(false);

  @override
  Future<void> disconnect({required String deviceId}) async {
    await _resetConnection(deviceId);
    _emitRegistrationState(deviceId, LgRegistrationState.failed);
  }

  // ---------------------------------------------------------------------------
  // SSAP
  // ---------------------------------------------------------------------------

  Future<void> _sendSsap({
    required String deviceId,
    required String uri,
    required Map<String, Object?> payload,
  }) async {
    if (_sockets[deviceId]?.readyState != WebSocket.open) {
      await connect(deviceId: deviceId);
    }
    final socket = _sockets[deviceId];
    if (socket == null || socket.readyState != WebSocket.open) {
      throw StateError('LG socket unavailable for $deviceId after connect.');
    }
    final id = 'req_${_reqCounter++}';
    socket.add(jsonEncode(buildLgSsapRequest(requestId: id, uri: uri, payload: payload)));
    emitTransportEvent(TransportEvent(
      transport: 'lg',
      deviceId: deviceId,
      type: 'ssap_sent',
      message: uri,
    ));
  }

  // ---------------------------------------------------------------------------
  // Pointer socket (dpad / back)
  // ---------------------------------------------------------------------------

  Future<void> _sendPointerCommand({
    required String deviceId,
    required String button,
  }) async {
    try {
      final pointerSocket = await _ensurePointerSocket(deviceId);
      final b = button.toLowerCase();
      pointerSocket.add('type:button\nbutton:$b\ndown:1\n\n');
      pointerSocket.add('type:button\nbutton:$b\ndown:0\n\n');
      emitTransportEvent(TransportEvent(
        transport: 'lg',
        deviceId: deviceId,
        type: 'pointer_sent',
        message: button,
      ));
    } on Object catch (e) {
      // webOS 2.x firmware may not provide a pointer socket.
      log(
        'LG pointer socket unavailable for $deviceId ($e). '
        'Dpad/back will not function on this firmware version.',
        name: 'lg_transport',
      );
    }
  }

  Future<WebSocket> _ensurePointerSocket(String deviceId) async {
    final existing = _pointerSockets[deviceId];
    if (existing != null && existing.readyState == WebSocket.open) return existing;

    final id = 'ptr_${_reqCounter++}';
    final completer = Completer<Map<String, dynamic>?>();
    _pendingRequests[id] = completer;

    final socket = _sockets[deviceId];
    if (socket == null || socket.readyState != WebSocket.open) {
      throw StateError('LG main socket not available for $deviceId.');
    }
    socket.add(jsonEncode(buildLgSsapRequest(
      requestId: id,
      uri: 'ssap://com.webos.service.networkinput/getPointerInputSocket',
      payload: const {},
    )));

    final response = await completer.future.timeout(connectTimeout);
    final socketPath =
        (response?['payload'] as Map<String, dynamic>?)?['socketPath'] as String?;
    if (socketPath == null || socketPath.isEmpty) {
      throw StateError('LG TV did not return a pointer socket path for $deviceId.');
    }

    final pointerSocket =
        await _openSocket(Uri.parse(socketPath)).timeout(connectTimeout);
    _pointerSockets[deviceId] = pointerSocket;
    _pointerSubs[deviceId]?.cancel();
    _pointerSubs[deviceId] = pointerSocket.listen(
      null,
      onDone: () => _pointerSockets.remove(deviceId),
      onError: (_) => _pointerSockets.remove(deviceId),
      cancelOnError: false,
    );
    return pointerSocket;
  }

  // ---------------------------------------------------------------------------
  // Socket binding and message handling
  // ---------------------------------------------------------------------------

  void _bindSocket({required String deviceId, required WebSocket socket}) {
    _sockets[deviceId] = socket;
    _subs[deviceId]?.cancel();
    _subs[deviceId] = socket.listen(
      (message) {
        if (message is! String) return;
        final decoded = _tryDecode(message);
        if (decoded != null) _handleMessage(deviceId: deviceId, decoded: decoded);
      },
      onDone: () {
        _subs.remove(deviceId);
        _sockets.remove(deviceId);
        _emitRegistrationState(deviceId, LgRegistrationState.failed);
        emitTransportEvent(TransportEvent(
          transport: 'lg',
          deviceId: deviceId,
          type: 'connection_closed',
        ));
      },
      onError: (Object error) {
        _subs.remove(deviceId);
        _sockets.remove(deviceId);
        _emitRegistrationState(deviceId, LgRegistrationState.failed);
        emitTransportEvent(TransportEvent(
          transport: 'lg',
          deviceId: deviceId,
          type: 'connection_error',
          message: error.toString(),
        ));
      },
      cancelOnError: false,
    );
  }

  void _handleMessage({
    required String deviceId,
    required Map<String, dynamic> decoded,
  }) {
    final type = decoded['type'] as String?;
    final id = decoded['id'] as String?;
    final payload = decoded['payload'] as Map<String, dynamic>?;
    final returnValue = payload?['returnValue'] as bool?;
    final clientKey = payload?['client-key'] as String?;

    // Resolve any pending request waiting on this response ID.
    if (id != null) _pendingRequests.remove(id)?.complete(decoded);

    if (type == 'registered') {
      if (returnValue == true) {
        _emitRegistrationState(deviceId, LgRegistrationState.registered);
        if (clientKey != null && clientKey.isNotEmpty) {
          _pairingCompleters[deviceId]?.complete(clientKey);
        }
      } else {
        _emitRegistrationState(deviceId, LgRegistrationState.failed);
        _pairingCompleters[deviceId]?.completeError(
          LgPairingRejectedException('LG TV rejected the pairing request.'),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<WebSocket> _openSocket(Uri uri) async {
    if (uri.scheme == 'wss') {
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      return WebSocket.connect(uri.toString(), customClient: client);
    }
    return WebSocket.connect(uri.toString());
  }

  Future<void> _resetConnection(String deviceId) async {
    _subs[deviceId]?.cancel();
    _subs.remove(deviceId);
    _pointerSubs[deviceId]?.cancel();
    _pointerSubs.remove(deviceId);
    _muteStates.remove(deviceId);
    _logGate.reset(deviceId);
    try {
      await _sockets.remove(deviceId)?.close();
    } catch (_) {}
    try {
      await _pointerSockets.remove(deviceId)?.close();
    } catch (_) {}
  }

  StreamController<LgRegistrationState> _registrationControllerFor(String deviceId) {
    return _registrationControllers.putIfAbsent(
      deviceId,
      () => StreamController<LgRegistrationState>.broadcast(),
    );
  }

  void _emitRegistrationState(String deviceId, LgRegistrationState state) {
    final ctrl = _registrationControllers[deviceId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(state);
  }

  Map<String, dynamic>? _tryDecode(String message) {
    try {
      final decoded = jsonDecode(message);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
