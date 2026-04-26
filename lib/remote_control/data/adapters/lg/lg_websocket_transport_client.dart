import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:one_remote/remote_control/application/text_input_compatibility_exception.dart';
import 'package:one_remote/remote_control/data/adapters/adapter_device_info_log_gate.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_exceptions.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_key_mapper.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_message_builder.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_pairing_key_store.dart';
import 'package:one_remote/remote_control/data/adapters/transport_command.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';

/// Real WebSocket transport for LG webOS TVs using the SSAP protocol.
///
/// Connection flow:
///   1. Tries wss://host:3001 (webOS 22+), falls back to ws://host:3000 (webOS 2–6).
///   2. Sends the 39-permission registration manifest immediately after connecting.
///      If a client-key is stored in [keyStore], it is included for silent reconnect.
///   3. First-time pairing: TV shows on-screen prompt; [requestClientKey] waits
///      for the user to approve and returns the issued client-key, which is then
///      persisted via [keyStore].
///   4. Reconnection with stored key: manifest includes the key; [connect] awaits
///      the registration confirmation before returning. If the key is stale the TV
///      returns returnValue:false — the store is cleared and
///      [LgPairingSessionExpiredException] is thrown so the caller can re-pair.
///
/// Dpad and back commands route via a separate pointer input socket obtained from
/// the TV. If the pointer socket is unavailable (webOS 2.x firmware), those
/// commands degrade gracefully with a logged warning rather than throwing.
class LgWebSocketTransportClient
    with TransportEventEmitterMixin
    implements LgTransportClient {
  static const int _tlsPort = 3001;
  static const int _plainPort = 3000;

  LgWebSocketTransportClient({
    required String Function(String deviceId) hostResolver,
    this.connectTimeout = const Duration(seconds: 8),
    LgPairingKeyStore? keyStore,
  }) : _hostResolver = hostResolver,
       _keyStore = keyStore;

  final String Function(String deviceId) _hostResolver;
  final Duration connectTimeout;
  final LgPairingKeyStore? _keyStore;

  final Map<String, WebSocket> _sockets = {};
  final Map<String, StreamSubscription<dynamic>> _subs = {};
  final Map<String, WebSocket> _pointerSockets = {};
  final Map<String, StreamSubscription<dynamic>> _pointerSubs = {};

  // Resolved by message handler when TV issues a client-key on first-time pairing.
  final Map<String, Completer<String>> _pairingCompleters = {};

  // Resolved (or failed) by message handler when registration response arrives.
  // Only populated when connect() is called with a stored key (reconnect flow).
  final Map<String, Completer<void>> _registrationCompleters = {};

  // Resolved by message handler for specific SSAP request IDs (e.g. pointer socket URL).
  final Map<String, Completer<Map<String, dynamic>?>> _pendingRequests = {};

  final Map<String, StreamController<LgRegistrationState>> _registrationControllers = {};

  // Tracks whether the current connect attempt included a stored key, so the
  // message handler can distinguish a stale-key rejection from a fresh rejection.
  final Map<String, bool> _hadStoredKey = {};

  // Devices that have completed registration (first-time pair or silent reconnect).
  // Used by requestClientKey() to return immediately on reconnect.
  final Set<String> _registeredDevices = {};

  // Mute defaults false; power defaults true (WebSocket implies TV is on); playing defaults true.
  final Map<String, Map<_RemoteStateKey, Object?>> _remoteStates = {};

  // IME subscription state for watchRemoteTextInputReady.
  final Map<String, StreamController<bool>> _imeReadyControllers = {};
  final Map<String, String> _imeSubIds = {};
  // Keyed by SSAP request ID; invoked on every matching response (unlike _pendingRequests).
  final Map<String, void Function(Map<String, dynamic>)> _subscriptionHandlers = {};

  late final _LgCommandFactory _commandFactory = _LgCommandFactory(this);

  final AdapterDeviceInfoLogGate _logGate = AdapterDeviceInfoLogGate();
  int _reqCounter = 0;

  @override
  Future<void> connect({required String deviceId}) async {
    final existing = _sockets[deviceId];
    if (existing != null && existing.readyState == WebSocket.open) return;

    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) throw StateError('LG host resolver returned empty host.');

    _emitRegistrationState(deviceId, LgRegistrationState.connecting);

    final storedKey = await _keyStore?.keyForHost(host);
    final hasStoredKey = storedKey != null && storedKey.isNotEmpty;
    _hadStoredKey[deviceId] = hasStoredKey;

    final uris = [
      Uri.parse('wss://$host:$_tlsPort'),
      Uri.parse('ws://$host:$_plainPort'),
    ];

    Object? lastError;
    for (final uri in uris) {
      // Create a fresh registration completer for each URI attempt when
      // reconnecting with a stored key so connect() can await confirmation.
      Completer<void>? registrationCompleter;
      if (hasStoredKey) {
        registrationCompleter = Completer<void>();
        _registrationCompleters[deviceId] = registrationCompleter;
      }

      log('LG connecting to $uri for $deviceId', name: 'lg_transport');
      try {
        final socket = await _openSocket(uri).timeout(connectTimeout);
        _bindSocket(deviceId: deviceId, socket: socket);
        socket.add(jsonEncode(buildLgRegisterPayload(clientKey: storedKey)));
        log('LG socket open, register sent → $uri for $deviceId', name: 'lg_transport');
        emitTransportEvent(TransportEvent(
          transport: 'lg',
          deviceId: deviceId,
          type: 'connected',
          message: '$host:${uri.port}',
        ));

        if (registrationCompleter != null) {
          await registrationCompleter.future.timeout(
            connectTimeout,
            onTimeout: () => throw StateError(
              'LG registration timed out for $deviceId at ${uri.host}:${uri.port}.',
            ),
          );
        }

        _registrationCompleters.remove(deviceId);
        return;
      } on Object catch (e) {
        log('LG connect failed ($uri) for $deviceId: $e', name: 'lg_transport');
        lastError = e;
        _registrationCompleters.remove(deviceId);
        await _resetConnection(deviceId);
        // Propagate session-expired immediately — retrying with a stale key
        // on a different port would just fail again.
        if (e is LgPairingSessionExpiredException) rethrow;
      }
    }

    _emitRegistrationState(deviceId, LgRegistrationState.failed);
    throw lastError ??
        StateError('Failed to connect to LG TV at $host.');
  }

  @override
  Future<String> requestClientKey({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_registeredDevices.contains(deviceId)) {
      final host = _hostResolver(deviceId).trim();
      final key = await _keyStore?.keyForHost(host);
      if (key != null && key.isNotEmpty) return key;
    }
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
  Future<void> sendKey({required String deviceId, required String keyCode}) =>
      _commandFactory.getCommand(deviceId, keyCode).execute();

  @override
  Future<void> sendText({required String deviceId, required String text}) async {
    final response = await _sendSsapWithResponse(
      deviceId: deviceId,
      uri: 'ssap://com.webos.service.ime/insertText',
      payload: {'text': text, 'replace': 0},
    );
    final returnValue =
        (response?['payload'] as Map<String, dynamic>?)?['returnValue'] as bool?;
    if (returnValue == false) {
      throw TextInputCompatibilityException(
        'LG IME text injection rejected — ensure a text field is focused on the TV.',
      );
    }
  }

  @override
  Stream<LgRegistrationState> watchRegistrationState(String deviceId) =>
      _registrationControllerFor(deviceId).stream;

  @override
  Stream<bool> watchRemoteTextInputReady(String deviceId) {
    final ctrl = _imeReadyControllers.putIfAbsent(
      deviceId,
      () => StreamController<bool>.broadcast(),
    );
    _ensureImeSubscription(deviceId);
    return ctrl.stream;
  }

  void _ensureImeSubscription(String deviceId) {
    if (_imeSubIds.containsKey(deviceId)) return;
    final socket = _sockets[deviceId];
    if (socket == null || socket.readyState != WebSocket.open) return;
    final id = 'ime_sub_${_reqCounter++}';
    _imeSubIds[deviceId] = id;
    _subscriptionHandlers[id] = (decoded) {
      final payload = decoded['payload'] as Map<String, dynamic>?;
      final currentWidget = payload?['currentWidget'] as Map<String, dynamic>?;
      final focus = currentWidget?['focus'] as bool?;
      if (focus != null) _imeReadyControllers[deviceId]?.add(focus);
    };
    socket.add(jsonEncode(buildLgSsapRequest(
      requestId: id,
      uri: 'ssap://com.webos.service.ime/registerRemoteKeyboard',
      payload: const {},
      type: 'subscribe',
    )));
  }

  @override
  Future<void> disconnect({required String deviceId}) async {
    await _resetConnection(deviceId);
    _emitRegistrationState(deviceId, LgRegistrationState.failed);
  }

  @override
  Future<void> clearPairing({required String deviceId}) async {
    final host = _hostResolver(deviceId).trim();
    await _resetConnection(deviceId);
    _emitRegistrationState(deviceId, LgRegistrationState.failed);
    if (host.isNotEmpty) {
      final clearFuture = _keyStore?.clearKeyForHost(host);
      if (clearFuture != null) await clearFuture;
    }
    _pairingCompleters.remove(deviceId);
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

  Future<Map<String, dynamic>?> _sendSsapWithResponse({
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
    final completer = Completer<Map<String, dynamic>?>();
    _pendingRequests[id] = completer;
    socket.add(jsonEncode(buildLgSsapRequest(requestId: id, uri: uri, payload: payload)));
    emitTransportEvent(TransportEvent(
      transport: 'lg',
      deviceId: deviceId,
      type: 'ssap_sent',
      message: uri,
    ));
    return completer.future.timeout(connectTimeout);
  }

  // ---------------------------------------------------------------------------
  // Pointer socket (dpad / back)
  // ---------------------------------------------------------------------------

  Future<void> _sendPointerCommand({
    required String deviceId,
    required String button,
  }) async {
    final pointerSocket = await _ensurePointerSocket(deviceId);
    pointerSocket.add("type:button\nname:$button\n\n");
    emitTransportEvent(TransportEvent(
      transport: 'lg',
      deviceId: deviceId,
      type: 'pointer_sent',
      message: button,
    ));
  }

  Future<WebSocket> _ensurePointerSocket(String deviceId) async {
    final existing = _pointerSockets[deviceId];
    if (existing != null && existing.readyState == WebSocket.open) return existing;

    if (_sockets[deviceId]?.readyState != WebSocket.open) {
      await connect(deviceId: deviceId);
    }
    final socket = _sockets[deviceId];
    if (socket == null || socket.readyState != WebSocket.open) {
      throw StateError('LG main socket unavailable for $deviceId after connect.');
    }

    final id = 'ptr_${_reqCounter++}';
    final completer = Completer<Map<String, dynamic>?>();
    _pendingRequests[id] = completer;
    socket.add(jsonEncode(buildLgSsapRequest(
      requestId: id,
      uri: 'ssap://com.webos.service.networkinput/getPointerInputSocket',
      payload: const {},
      type: 'request',
    )));

    final response = await completer.future.timeout(connectTimeout);
    final socketPath =
        (response?['payload'] as Map<String, dynamic>?)?['socketPath'] as String?;
    if (socketPath == null || socketPath.isEmpty) {
      throw StateError(
        'LG pointer socket unavailable for $deviceId. '
        'TV response: $response',
      );
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
    final clientKey = payload?['client-key'] as String?;
    final returnValue = payload?['returnValue'] as bool?;

    // Resolve any pending SSAP request waiting on this response ID.
    if (id != null) _pendingRequests.remove(id)?.complete(decoded);
    // Forward to subscription handlers (persistent; not removed on fire).
    if (id != null) _subscriptionHandlers[id]?.call(decoded);

    // Registration response: TV sends type:"registered" (first-time pair or echoed key)
    // OR type:"response" with id:"register_0" on reconnect (some firmware skips "registered").
    // The type:"response" guard requires a stored key so intermediate ack messages sent
    // during first-time pairing (before user approves the prompt) are not misread as rejections.
    final isRegistrationResponse = type == 'registered' ||
        (type == 'response' &&
            id == 'register_0' &&
            _hadStoredKey[deviceId] == true);

    if (isRegistrationResponse) {
      if (clientKey != null && clientKey.isNotEmpty) {
        // TV issued or echoed a client-key → success for any pairing scenario.
        _emitRegistrationState(deviceId, LgRegistrationState.registered);
        _registrationCompleters.remove(deviceId)?.complete();
        final host = _hostResolver(deviceId).trim();
        final storeFuture = _keyStore?.storeKeyForHost(host, clientKey);
        if (storeFuture != null) unawaited(storeFuture);
        _pairingCompleters[deviceId]?.complete(clientKey);
      } else if (_hadStoredKey[deviceId] == true && returnValue != false) {
        // Silent reconnect: TV accepted our stored key but didn't echo it back.
        _emitRegistrationState(deviceId, LgRegistrationState.registered);
        _registrationCompleters.remove(deviceId)?.complete();
      } else {
        // No client-key, not a valid silent reconnect → rejection.
        _emitRegistrationState(deviceId, LgRegistrationState.failed);
        if (_hadStoredKey[deviceId] == true) {
          final host = _hostResolver(deviceId).trim();
          final clearFuture = _keyStore?.clearKeyForHost(host);
          if (clearFuture != null) unawaited(clearFuture);
          final error = LgPairingSessionExpiredException(
            'LG TV rejected the stored client-key for $deviceId. Re-pairing required.',
          );
          _registrationCompleters.remove(deviceId)?.completeError(error);
          _pairingCompleters[deviceId]?.completeError(error);
        } else {
          final error = LgPairingRejectedException('LG TV rejected the pairing request.');
          _registrationCompleters.remove(deviceId)?.completeError(error);
          _pairingCompleters[deviceId]?.completeError(error);
        }
      }
    } else if (type == 'error') {
      // webOS 3.x+ sends type:"error" when the user dismisses the pairing prompt.
      // Guard to avoid interfering with SSAP command error responses.
      final hasPairingWaiter = _pairingCompleters.containsKey(deviceId) ||
          _registrationCompleters.containsKey(deviceId);
      if (hasPairingWaiter) {
        _emitRegistrationState(deviceId, LgRegistrationState.failed);
        if (_hadStoredKey[deviceId] == true) {
          final host = _hostResolver(deviceId).trim();
          final clearFuture = _keyStore?.clearKeyForHost(host);
          if (clearFuture != null) unawaited(clearFuture);
          final error = LgPairingSessionExpiredException(
            'LG TV rejected the stored client-key for $deviceId. Re-pairing required.',
          );
          _registrationCompleters.remove(deviceId)?.completeError(error);
          _pairingCompleters[deviceId]?.completeError(error);
        } else {
          final error = LgPairingRejectedException('LG TV rejected the pairing request.');
          _registrationCompleters.remove(deviceId)?.completeError(error);
          _pairingCompleters[deviceId]?.completeError(error);
        }
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> querySystemInfo({required String deviceId}) async {
    try {
      final response = await _sendSsapWithResponse(
        deviceId: deviceId,
        uri: 'ssap://system/getSystemInfo',
        payload: const {},
      );
      return response?['payload'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
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
    _hadStoredKey.remove(deviceId);
    _registeredDevices.remove(deviceId);
    _remoteStates.remove(deviceId);
    final subId = _imeSubIds.remove(deviceId);
    if (subId != null) _subscriptionHandlers.remove(subId);
    final imeCtrl = _imeReadyControllers.remove(deviceId);
    if (imeCtrl != null && !imeCtrl.isClosed) {
      imeCtrl.add(false);
      imeCtrl.close();
    }
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
    if (state == LgRegistrationState.registered) {
      _registeredDevices.add(deviceId);
    } else {
      _registeredDevices.remove(deviceId);
    }
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
    throw SocketException('$host unreachable on LG ports');
  }
}

// ---------------------------------------------------------------------------
// Command dispatch
// ---------------------------------------------------------------------------

enum _RemoteStateKey { mute, power, playing }

class _LgTransportCommand implements TransportCommand {
  _LgTransportCommand(this._action);
  final Future<void> Function() _action;

  @override
  Future<void> execute() => _action();
}

class _LgCommandFactory implements TransportCommandFactory {
  _LgCommandFactory(this._client);
  final LgWebSocketTransportClient _client;

  @override
  TransportCommand getCommand(String deviceId, String keyCode) {
    if (keyCode.startsWith(lgPointerPrefix)) {
      final button = keyCode.substring(lgPointerPrefix.length);
      return _LgTransportCommand(
        () => _client._sendPointerCommand(deviceId: deviceId, button: button),
      );
    }
    if (keyCode.startsWith(lgLaunchPrefix)) {
      final appId = keyCode.substring(lgLaunchPrefix.length);
      return _LgTransportCommand(
        () => _client._sendSsap(
          deviceId: deviceId,
          uri: 'ssap://system.launcher/launch',
          payload: {'id': appId},
        ),
      );
    }
    if (keyCode == 'ssap://audio/setMute') {
      return _LgTransportCommand(() async {
        final newMute = !(_client._remoteStates[deviceId]?[_RemoteStateKey.mute] as bool? ?? false);
        (_client._remoteStates[deviceId] ??= {})[_RemoteStateKey.mute] = newMute;
        await _client._sendSsap(
          deviceId: deviceId,
          uri: keyCode,
          payload: {'mute': newMute},
        );
      });
    }
    if (keyCode == lgPowerToggleKey) {
      return _LgTransportCommand(() async {
        final newPower = !(_client._remoteStates[deviceId]?[_RemoteStateKey.power] as bool? ?? true);
        (_client._remoteStates[deviceId] ??= {})[_RemoteStateKey.power] = newPower;
        await _client._sendSsap(
          deviceId: deviceId,
          uri: newPower ? 'ssap://system/turnOn' : 'ssap://system/turnOff',
          payload: const {},
        );
      });
    }
    if (keyCode == lgPlayPauseToggleKey) {
      return _LgTransportCommand(() async {
        final nowPlaying = !(_client._remoteStates[deviceId]?[_RemoteStateKey.playing] as bool? ?? true);
        (_client._remoteStates[deviceId] ??= {})[_RemoteStateKey.playing] = nowPlaying;
        await _client._sendSsap(
          deviceId: deviceId,
          uri: nowPlaying ? 'ssap://media.controls/play' : 'ssap://media.controls/pause',
          payload: const {},
        );
      });
    }
    return _LgTransportCommand(
      () => _client._sendSsap(deviceId: deviceId, uri: keyCode, payload: const {}),
    );
  }
}
