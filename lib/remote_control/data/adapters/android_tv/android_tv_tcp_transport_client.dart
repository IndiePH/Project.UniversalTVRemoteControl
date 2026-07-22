import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_certificate_store.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_exceptions.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_handshake_tracer.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_pairing_messages.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_remote_messages.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

/// TCP+TLS transport for the Android TV v2 remote protocol.
///
/// Task 8: pairing flow (port 6467, mutual TLS, Polo protobuf).
/// Task 9: remote-control flow (port 6466, mutual TLS, RemoteMessage protobuf).
///
/// Wire framing on both ports: protobuf varint length prefix (verified from
/// base.py in tronikos/androidtvremote2 — the goal file's "4-byte big-endian"
/// note was incorrect).
class AndroidTvTcpTransportClient
    with TransportEventEmitterMixin
    implements AndroidTvTransportClient {
  static const int _pairingPort = 6467;
  static const int _remotePort = 6466;

  // Protocol constants verified from the Polo pairing specification.
  static const String _serviceName = 'atvremote';
  static const String _clientName = 'OneRemote';

  // Client feature bitmask for RemoteSetActive handshake response.
  // PING=1, KEY=2, IME=4, VOICE=8, POWER=32, VOLUME=64, APP_LINK=512
  static const int _remoteClientFeatures = 1 | 2 | 4 | 8 | 32 | 64 | 512;

  AndroidTvTcpTransportClient({
    required this._hostResolver,
    required this._certStore,
    this._tracer,
    this.connectTimeout = const Duration(seconds: 8),
  });

  final String Function(String deviceId) _hostResolver;
  final AndroidTvCertificateStore _certStore;
  final AndroidTvHandshakeTracer? _tracer;
  final Duration connectTimeout;

  // Pairing state, keyed by deviceId
  final Map<String, SecureSocket> _pairingSockets = {};
  final Map<String, StreamSubscription<List<int>>> _pairingSubs = {};
  final Map<String, List<int>> _pairingBuffers = {};
  final Map<String, (BigInt, BigInt)> _serverRsa = {}; // (modulus, exponent)
  final Map<String, Uint8List> _serverCertDers = {};
  final Map<String, Completer<void>> _pairingStartedCompleters = {};
  final Map<String, Completer<void>> _secretAckCompleters = {};

  // Remote control state, keyed by deviceId
  final Map<String, SecureSocket> _remoteSockets = {};
  final Map<String, StreamSubscription<List<int>>> _remoteSubs = {};
  final Map<String, List<int>> _remoteBuffers = {};
  final Map<String, int> _imeCounters = {};
  final Map<String, int> _fieldCounters = {};
  final Map<String, Completer<void>> _remoteStartedCompleters = {};
  // Negotiated features = _remoteClientFeatures & TV's code1 from RemoteConfigure.
  final Map<String, int> _remoteNegotiatedFeatures = {};

  // _remoteActive tracks devices with intentional remote connections so
  // _onRemoteSocketDone can distinguish unexpected closes (reconnect) from
  // explicit clearPairing() calls (do not reconnect).
  final Set<String> _remoteActive = {};
  final Set<String> _remoteConnecting = {};

  // Connection state, keyed by deviceId
  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      {};
  final Map<String, ConnectionState> _lastConnectionStates = {};

  // ---------------------------------------------------------------------------
  // AndroidTvTransportClient interface
  // ---------------------------------------------------------------------------

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _controllerFor(deviceId).stream;

  /// Routes to the pairing flow (port 6467) if no server cert is stored,
  /// or to the remote-control flow (port 6466) if already paired.
  /// Idempotent on the remote path: returns immediately if already connected.
  @override
  Future<void> connect({required String deviceId}) async {
    final host = _hostResolver(deviceId);
    final isPaired = await _certStore.serverRsaComponents(host) != null;
    if (isPaired) {
      await _connectRemote(deviceId);
    } else {
      await _connectPairing(deviceId);
    }
  }

  /// Computes the SHA-256 pairing secret from [code] and the captured server
  /// certificate RSA components, sends it to the TV, and awaits confirmation.
  /// Persists the server certificate to disk only on success.
  @override
  Future<void> submitPairingCode({
    required String deviceId,
    required String code,
  }) async {
    final rsa = _serverRsa[deviceId];
    if (rsa == null) {
      throw const AndroidTvPairingFailedException(
        'No server certificate — call connect() first',
      );
    }

    final (serverMod, serverExp) = rsa;
    final secretBytes = await _computeSecret(code, serverMod, serverExp);

    _secretAckCompleters[deviceId] = Completer<void>();
    _sendPairingMessage(
      deviceId,
      OuterMessage(
        protocolVersion: 2,
        status: PairingStatus.statusOk,
        secret: Secret(secret: secretBytes),
      ),
    );

    await _secretAckCompleters[deviceId]!.future;

    // Only persist the cert after pairing is confirmed successful.
    final der = _serverCertDers[deviceId];
    if (der != null) {
      await _certStore.storeServerCert(_hostResolver(deviceId), der);
    }

    emitTransportEvent(
      TransportEvent(
        transport: 'android_tv',
        deviceId: deviceId,
        type: 'paired',
      ),
    );

    _cleanupPairing(deviceId);
  }

  /// Sends a key event to the TV via the remote-control channel.
  /// [keyCode] is the string-encoded integer from [AndroidTvKeyMapper].
  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    _sendRemoteMessage(
      deviceId,
      RemoteMessage(
        remoteKeyInject: RemoteKeyInject(
          keyCode: int.parse(keyCode),
          direction: RemoteDirection.short,
        ),
      ),
    );
  }

  /// Sends text input via a RemoteImeBatchEdit message, using the IME counters
  /// that were last received from the TV.
  @override
  Future<void> sendText({
    required String deviceId,
    required String text,
  }) async {
    final len = text.length;
    final imeObject = RemoteImeObject(
      start: len - 1,
      end: len - 1,
      value: text,
    );
    final editInfo = RemoteEditInfo(insert: 1, textFieldStatus: imeObject);
    final batchEdit = RemoteImeBatchEdit(
      imeCounter: _imeCounters[deviceId] ?? 0,
      fieldCounter: _fieldCounters[deviceId] ?? 0,
      editInfo: [editInfo],
    );
    _sendRemoteMessage(deviceId, RemoteMessage(remoteImeBatchEdit: batchEdit));
  }

  @override
  Future<void> sendAppLink({
    required String deviceId,
    required String appLink,
  }) async {
    _sendRemoteMessage(
      deviceId,
      RemoteMessage(
        remoteAppLinkLaunchRequest: RemoteAppLinkLaunchRequest(
          appLink: appLink,
        ),
      ),
    );
  }

  /// TCP reachability check against the remote-control port (6466).
  @override
  Future<void> probe(String host) async {
    final socket = await Socket.connect(
      host,
      _remotePort,
      timeout: const Duration(seconds: 3),
    );
    socket.destroy();
  }

  /// Unblocks any in-progress pairing handshake and tears down the pairing
  /// socket. Must call [_failPendingPairing] before [_cleanupPairing] so the
  /// awaited Completer resolves before its map entry is removed.
  @override
  void cancelPairing(String deviceId) {
    _failPendingPairing(
      deviceId,
      const AndroidTvConnectionException('Pairing cancelled'),
    );
    _cleanupPairing(deviceId);
  }

  /// Prevents reconnect, closes both sockets, and removes the stored server
  /// certificate so the device can be re-paired from scratch.
  @override
  Future<void> clearPairing({required String deviceId}) async {
    // Remove from _remoteActive before destroying the socket so that
    // _onRemoteSocketDone does not schedule a reconnect.
    _remoteActive.remove(deviceId);
    _cleanupPairing(deviceId);
    _cleanupRemote(deviceId);
    await _certStore.clearServerCert(_hostResolver(deviceId));
    _emitState(deviceId, ConnectionState.disconnected);
  }

  @override
  Future<TvDeviceInfo> queryDeviceInfo({required String deviceId}) async =>
      const TvDeviceInfo();

  // ---------------------------------------------------------------------------
  // Pairing flow (port 6467)
  // ---------------------------------------------------------------------------

  Future<void> _connectPairing(String deviceId) async {
    final host = _hostResolver(deviceId);
    _emitState(deviceId, ConnectionState.connecting);

    try {
      final ctx = await _certStore.clientContext;
      final socket = await SecureSocket.connect(
        host,
        _pairingPort,
        context: ctx,
        // Android TV uses self-signed certs; we capture and store the peer cert
        // manually rather than relying on the system trust store.
        onBadCertificate: (_) => true,
        timeout: connectTimeout,
      );

      // Extract server cert RSA components now so submitPairingCode can use them
      // without additional disk I/O during the time-sensitive PIN entry window.
      final rawDer = socket.peerCertificate?.der;
      if (rawDer != null) {
        final der = Uint8List.fromList(rawDer);
        _serverCertDers[deviceId] = der;
        final rsa = AndroidTvCertificateStore.extractRsaFromDer(der);
        if (rsa != null) _serverRsa[deviceId] = rsa;
      }

      _pairingSockets[deviceId] = socket;
      _pairingBuffers[deviceId] = [];
      _tracer?.init(deviceId);
      _pairingStartedCompleters[deviceId] = Completer<void>();

      _pairingSubs[deviceId] = socket.listen(
        (data) => _onPairingData(deviceId, data),
        onError: (Object e) => _onPairingSocketError(deviceId, e),
        onDone: () => _onPairingSocketDone(deviceId),
        cancelOnError: true,
      );

      _sendPairingMessage(
        deviceId,
        OuterMessage(
          protocolVersion: 2,
          status: PairingStatus.statusOk,
          pairingRequest: PairingRequest(
            serviceName: _serviceName,
            clientName: _clientName,
          ),
        ),
      );

      // Blocks until configuration_ack — the TV now shows the PIN.
      // Timeout guards against TVs that accept TLS but don't speak POLO.
      await _pairingStartedCompleters[deviceId]!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          final detail = _tracer?.summary(deviceId) ?? '';
          throw AndroidTvConnectionException(
            detail.isEmpty
                ? 'Pairing handshake timed out — check TV is on and reachable'
                : 'Pairing handshake timed out ($detail)',
          );
        },
      );
      _emitState(deviceId, ConnectionState.connected);
    } catch (e) {
      _emitState(deviceId, ConnectionState.error);
      _cleanupPairing(deviceId);
      if (e is AndroidTvPairingFailedException ||
          e is AndroidTvConnectionException) {
        rethrow;
      }
      throw AndroidTvConnectionException(e.toString());
    }
  }

  void _onPairingData(String deviceId, List<int> data) {
    _tracer?.recordBytes(deviceId, data);
    _pairingBuffers[deviceId]?.addAll(data);
    _drainPairingBuffer(deviceId);
  }

  void _drainPairingBuffer(String deviceId) {
    final buf = _pairingBuffers[deviceId];
    if (buf == null) return;

    while (true) {
      final varint = _tryDecodeVarint(buf);
      if (varint == null) return;

      final (msgLen, consumed) = varint;
      if (buf.length < consumed + msgLen) return;

      final msgBytes = Uint8List.fromList(
        buf.sublist(consumed, consumed + msgLen),
      );
      buf.removeRange(0, consumed + msgLen);

      try {
        _handlePairingMessage(deviceId, OuterMessage.fromBuffer(msgBytes));
      } catch (e) {
        final hex = msgBytes
            .take(32)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        _failPendingPairing(
          deviceId,
          AndroidTvConnectionException(
            'Pairing decode error — ${msgBytes.length} bytes: $hex ($e)',
          ),
        );
      }
    }
  }

  void _handlePairingMessage(String deviceId, OuterMessage msg) {
    log(
      'Android TV pairing rx: ${msg.toDebugString()}',
      name: 'android_tv_transport',
    );

    if (msg.hasPairingRequestAck()) {
      // Step 3: inform the TV of supported encoding options.
      _sendPairingMessage(
        deviceId,
        OuterMessage(
          protocolVersion: 2,
          status: PairingStatus.statusOk,
          options: Options(
            preferredRole: RoleType.input,
            inputEncodings: [
              OptionsEncoding(type: EncodingType.hexadecimal, symbolLength: 6),
            ],
          ),
        ),
      );
    } else if (msg.hasOptions()) {
      // Step 5: TV replied with its options — client confirms chosen encoding.
      _sendPairingMessage(
        deviceId,
        OuterMessage(
          protocolVersion: 2,
          status: PairingStatus.statusOk,
          configuration: Configuration(
            clientRole: RoleType.input,
            encoding: OptionsEncoding(
              type: EncodingType.hexadecimal,
              symbolLength: 6,
            ),
          ),
        ),
      );
    } else if (msg.hasConfigurationAck()) {
      // Step 6: TV confirmed configuration — PIN is now visible on screen.
      final c = _pairingStartedCompleters[deviceId];
      if (c != null && !c.isCompleted) c.complete();
    } else if (msg.hasSecretAck()) {
      final c = _secretAckCompleters[deviceId];
      if (c == null || c.isCompleted) return;
      if (msg.status == PairingStatus.statusOk) {
        c.complete();
      } else {
        c.completeError(
          AndroidTvPairingFailedException('status ${msg.status.value}'),
        );
      }
    }
  }

  void _onPairingSocketError(String deviceId, Object error) {
    log(
      'Android TV pairing socket error: $error',
      name: 'android_tv_transport',
    );
    _failPendingPairing(
      deviceId,
      AndroidTvConnectionException(error.toString()),
    );
    _cleanupPairing(deviceId);
    _emitState(deviceId, ConnectionState.error);
  }

  void _onPairingSocketDone(String deviceId) {
    log('Android TV pairing socket closed', name: 'android_tv_transport');
    _failPendingPairing(
      deviceId,
      const AndroidTvConnectionException('Socket closed unexpectedly'),
    );
    _cleanupPairing(deviceId);
  }

  void _failPendingPairing(String deviceId, Object error) {
    final c1 = _pairingStartedCompleters[deviceId];
    if (c1 != null && !c1.isCompleted) c1.completeError(error);

    final c2 = _secretAckCompleters[deviceId];
    if (c2 != null && !c2.isCompleted) c2.completeError(error);
  }

  void _sendPairingMessage(String deviceId, OuterMessage msg) {
    final socket = _pairingSockets[deviceId];
    if (socket == null) return;
    log(
      'Android TV pairing tx: ${msg.toDebugString()}',
      name: 'android_tv_transport',
    );
    final payload = msg.writeToBuffer();
    socket.add(_encodeVarint(payload.length));
    socket.add(payload);
  }

  void _cleanupPairing(String deviceId) {
    _pairingSubs.remove(deviceId)?.cancel();
    _pairingSockets.remove(deviceId)?.destroy();
    _pairingBuffers.remove(deviceId);
    _tracer?.dispose(deviceId);
    _serverCertDers.remove(deviceId);
    _serverRsa.remove(deviceId);
    _pairingStartedCompleters.remove(deviceId);
    _secretAckCompleters.remove(deviceId);
  }

  // ---------------------------------------------------------------------------
  // Remote control flow (port 6466)
  // ---------------------------------------------------------------------------

  Future<void> _connectRemote(String deviceId) async {
    if (_remoteSockets[deviceId] != null) return; // already connected
    if (_remoteConnecting.contains(deviceId)) return; // connect in flight

    _remoteConnecting.add(deviceId);
    final host = _hostResolver(deviceId);
    _emitState(deviceId, ConnectionState.connecting);

    try {
      final ctx = await _certStore.clientContext;
      final socket = await SecureSocket.connect(
        host,
        _remotePort,
        context: ctx,
        onBadCertificate: (_) => true,
        timeout: connectTimeout,
      );

      log(
        'Android TV remote TLS connected to $host:$_remotePort — awaiting RemoteConfigure',
        name: 'android_tv_transport',
      );

      _remoteSockets[deviceId] = socket;
      _remoteBuffers[deviceId] = [];
      _tracer?.init(deviceId);
      _remoteStartedCompleters[deviceId] = Completer<void>();

      _remoteSubs[deviceId] = socket.listen(
        (data) => _onRemoteData(deviceId, data),
        onError: (Object e) => _onRemoteSocketError(deviceId, e),
        onDone: () => _onRemoteSocketDone(deviceId),
        cancelOnError: true,
      );

      // Server speaks first: RemoteConfigure → RemoteSetActive → RemoteStart.
      // _handleRemoteMessage drives the handshake responses; we wait here for
      // RemoteStart before advertising the connection as ready.
      await _remoteStartedCompleters[deviceId]!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          final detail = _tracer?.summary(deviceId) ?? '';
          throw AndroidTvConnectionException(
            detail.isEmpty
                ? 'Remote handshake timed out — check TV is on and reachable'
                : 'Remote handshake timed out ($detail)',
          );
        },
      );

      _remoteActive.add(deviceId);
      _emitState(deviceId, ConnectionState.connected);
    } catch (e) {
      _emitState(deviceId, ConnectionState.error);
      _cleanupRemote(deviceId);
      if (e is AndroidTvConnectionException) rethrow;
      throw AndroidTvConnectionException(e.toString());
    } finally {
      _remoteConnecting.remove(deviceId);
    }
  }

  void _onRemoteData(String deviceId, List<int> data) {
    log(
      'Android TV remote raw rx (${data.length}B): '
      '${data.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}'
      '${data.length > 32 ? '…' : ''}',
      name: 'android_tv_transport',
    );
    _tracer?.recordBytes(deviceId, data);
    _remoteBuffers[deviceId]?.addAll(data);
    _drainRemoteBuffer(deviceId);
  }

  void _drainRemoteBuffer(String deviceId) {
    final buf = _remoteBuffers[deviceId];
    if (buf == null) return;

    while (true) {
      final varint = _tryDecodeVarint(buf);
      if (varint == null) return;

      final (msgLen, consumed) = varint;
      if (buf.length < consumed + msgLen) return;

      final msgBytes = Uint8List.fromList(
        buf.sublist(consumed, consumed + msgLen),
      );
      buf.removeRange(0, consumed + msgLen);

      try {
        _handleRemoteMessage(deviceId, RemoteMessage.fromBuffer(msgBytes));
      } catch (e) {
        final errStr = e.toString();
        _tracer?.recordEvent(
          deviceId,
          'decode_err:${errStr.length > 80 ? errStr.substring(0, 80) : errStr}',
        );
        log(
          'Android TV: remote message decode error: $e',
          name: 'android_tv_transport',
        );
      }
    }
  }

  void _handleRemoteMessage(String deviceId, RemoteMessage msg) {
    log(
      'Android TV remote rx: ${msg.toDebugString()}',
      name: 'android_tv_transport',
    );

    if (msg.hasRemoteConfigure()) {
      final negotiated = _remoteClientFeatures & msg.remoteConfigure.code1;
      _remoteNegotiatedFeatures[deviceId] = negotiated;
      _tracer?.recordEvent(
        deviceId,
        'rx:RemoteConfigure(code1=${msg.remoteConfigure.code1},negotiated=$negotiated)',
      );
      // Server initiates handshake — echo code1, send our device info.
      _sendRemoteMessage(
        deviceId,
        RemoteMessage(
          remoteConfigure: RemoteConfigure(
            code1: msg.remoteConfigure.code1,
            deviceInfo: RemoteDeviceInfo(
              unknown1: 1,
              unknown2: '1',
              packageName: 'atvremote',
              appVersion: '1.0.0',
            ),
          ),
        ),
      );
      _tracer?.recordEvent(deviceId, 'tx:RemoteConfigure');
    } else if (msg.hasRemoteSetActive()) {
      // TV sends its own active bitmask; we respond with our negotiated features.
      final features =
          _remoteNegotiatedFeatures[deviceId] ?? _remoteClientFeatures;
      _tracer?.recordEvent(
        deviceId,
        'rx:RemoteSetActive(active=${msg.remoteSetActive.active})',
      );
      _sendRemoteMessage(
        deviceId,
        RemoteMessage(remoteSetActive: RemoteSetActive(active: features)),
      );
      _tracer?.recordEvent(deviceId, 'tx:RemoteSetActive(active=$features)');
    } else if (msg.hasRemoteStart()) {
      _tracer?.recordEvent(
        deviceId,
        'rx:RemoteStart(started=${msg.remoteStart.started})',
      );
      // Handshake complete — unblock _connectRemote.
      final c = _remoteStartedCompleters[deviceId];
      if (c != null && !c.isCompleted) c.complete();
    } else if (msg.hasRemotePingRequest()) {
      _sendRemoteMessage(
        deviceId,
        RemoteMessage(
          remotePingResponse: RemotePingResponse(
            val1: msg.remotePingRequest.val1,
          ),
        ),
      );
    } else if (msg.hasRemoteImeBatchEdit()) {
      // Sync IME counters from TV so subsequent sendText calls use correct values.
      _imeCounters[deviceId] = msg.remoteImeBatchEdit.imeCounter;
      _fieldCounters[deviceId] = msg.remoteImeBatchEdit.fieldCounter;
    }
  }

  void _onRemoteSocketError(String deviceId, Object error) {
    log('Android TV remote socket error: $error', name: 'android_tv_transport');
    _cleanupRemote(deviceId);
    _emitState(deviceId, ConnectionState.error);
  }

  void _onRemoteSocketDone(String deviceId) async {
    log('Android TV remote socket closed', name: 'android_tv_transport');
    _cleanupRemote(deviceId);
    _emitState(deviceId, ConnectionState.disconnected);

    // _remoteActive is cleared by clearPairing() before socket.destroy() is
    // called, so its absence here means an intentional disconnect — skip reconnect.
    if (!_remoteActive.contains(deviceId)) return;

    await Future<void>.delayed(const Duration(seconds: 3));
    _emitState(deviceId, ConnectionState.connecting);
    try {
      await _connectRemote(deviceId);
    } catch (e) {
      log('Android TV: reconnect failed: $e', name: 'android_tv_transport');
      _remoteActive.remove(deviceId);
      _emitState(deviceId, ConnectionState.error);
    }
  }

  void _sendRemoteMessage(String deviceId, RemoteMessage msg) {
    final socket = _remoteSockets[deviceId];
    if (socket == null) return;
    log(
      'Android TV remote tx: ${msg.toDebugString()}',
      name: 'android_tv_transport',
    );
    final payload = msg.writeToBuffer();
    socket.add(_encodeVarint(payload.length));
    socket.add(payload);
  }

  void _cleanupRemote(String deviceId) {
    _remoteSubs.remove(deviceId)?.cancel();
    _remoteSockets.remove(deviceId)?.destroy();
    _remoteBuffers.remove(deviceId);
    _remoteNegotiatedFeatures.remove(deviceId);
    _tracer?.dispose(deviceId);
    _imeCounters.remove(deviceId);
    _fieldCounters.remove(deviceId);
    final c = _remoteStartedCompleters.remove(deviceId);
    if (c != null && !c.isCompleted) {
      c.completeError(
        const AndroidTvConnectionException('Remote connection closed'),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Secret computation (pairing)
  // ---------------------------------------------------------------------------

  Future<List<int>> _computeSecret(
    String pairingCode,
    BigInt serverMod,
    BigInt serverExp,
  ) async {
    final clientMod = await _certStore.clientModulus;
    final clientExp = await _certStore.clientExponent;

    final data = <int>[
      ..._bigIntBytes(clientMod, prependZero: false),
      ..._bigIntBytes(clientExp, prependZero: true),
      ..._bigIntBytes(serverMod, prependZero: false),
      ..._bigIntBytes(serverExp, prependZero: true),
      ..._fromHex(pairingCode.substring(2)), // last 4 hex chars → 2 bytes
    ];
    final digest = sha256.convert(data).bytes;

    // The first byte of the digest must equal the first two hex chars of the
    // code. This catches user input errors without needing a server round-trip.
    final checkByte = int.parse(pairingCode.substring(0, 2), radix: 16);
    if (digest[0] != checkByte) {
      throw const AndroidTvPairingFailedException(
        'Pairing code checksum mismatch — check the code and try again',
      );
    }

    return digest;
  }

  // Converts a BigInt to a big-endian byte list matching the protocol formula.
  // prependZero: prepend one hex '0' digit before converting (matches exponent
  // encoding in the secret formula).
  static List<int> _bigIntBytes(BigInt value, {required bool prependZero}) {
    var hex = value.toRadixString(16).toUpperCase();
    if (prependZero) hex = '0$hex';
    if (hex.length.isOdd) hex = '0$hex'; // ensure even hex digit count
    return _fromHex(hex);
  }

  static List<int> _fromHex(String hex) {
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Varint encoding/decoding (protobuf wire format for length prefix)
  // ---------------------------------------------------------------------------

  static List<int> _encodeVarint(int value) {
    final out = <int>[];
    while (value > 0x7F) {
      out.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    out.add(value);
    return out;
  }

  // Returns (messageLength, varintBytesConsumed) or null if more bytes needed.
  static (int, int)? _tryDecodeVarint(List<int> buf) {
    int result = 0;
    int shift = 0;
    for (var i = 0; i < buf.length; i++) {
      final byte = buf[i];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return (result, i + 1);
      shift += 7;
      if (shift >= 32) return null; // corrupt stream guard
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Connection state helpers
  // ---------------------------------------------------------------------------

  StreamController<ConnectionState> _controllerFor(String deviceId) =>
      _connectionControllers.putIfAbsent(
        deviceId,
        () => StreamController<ConnectionState>.broadcast(
          onListen: () {
            final last =
                _lastConnectionStates[deviceId] ?? ConnectionState.disconnected;
            _connectionControllers[deviceId]?.add(last);
          },
        ),
      );

  void _emitState(String deviceId, ConnectionState state) {
    if (_lastConnectionStates[deviceId] == state) return;
    _lastConnectionStates[deviceId] = state;
    final ctrl = _connectionControllers[deviceId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(state);
  }
}
