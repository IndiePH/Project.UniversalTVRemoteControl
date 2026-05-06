import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_certificate_store.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_exceptions.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_pairing_messages.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

/// TCP+TLS transport for the Android TV v2 remote protocol.
///
/// Task 8 covers the pairing flow (port 6467, mutual TLS, Polo protobuf).
/// Task 9 will complete this class with the remote-control flow (port 6466).
class AndroidTvTcpTransportClient
    with TransportEventEmitterMixin
    implements AndroidTvTransportClient {
  static const int _pairingPort = 6467;
  static const int _remotePort = 6466;

  // Protocol constants verified from the Polo pairing specification.
  static const String _serviceName = 'atvremote';
  static const String _clientName = 'OneRemote';

  AndroidTvTcpTransportClient({
    required String Function(String deviceId) hostResolver,
    required AndroidTvCertificateStore certStore,
    this.connectTimeout = const Duration(seconds: 8),
  })  : _hostResolver = hostResolver,
        _certStore = certStore;

  final String Function(String deviceId) _hostResolver;
  final AndroidTvCertificateStore _certStore;
  final Duration connectTimeout;

  // Pairing state, keyed by deviceId
  final Map<String, SecureSocket> _pairingSockets = {};
  final Map<String, StreamSubscription<List<int>>> _pairingSubs = {};
  final Map<String, List<int>> _pairingBuffers = {};
  final Map<String, (BigInt, BigInt)> _serverRsa = {}; // (modulus, exponent)
  final Map<String, Uint8List> _serverCertDers = {};
  final Map<String, Completer<void>> _pairingStartedCompleters = {};
  final Map<String, Completer<void>> _secretAckCompleters = {};

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

  /// Connects to the TV pairing port (6467) using mutual TLS, sends the
  /// pairing request, and returns once the TV shows the PIN on screen
  /// (i.e. after the configuration_ack exchange completes).
  @override
  Future<void> connect({required String deviceId}) async {
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
      _pairingStartedCompleters[deviceId] = Completer<void>();

      _pairingSubs[deviceId] = socket.listen(
        (data) => _onData(deviceId, data),
        onError: (Object e) => _onSocketError(deviceId, e),
        onDone: () => _onSocketDone(deviceId),
        cancelOnError: true,
      );

      _sendMessage(
        deviceId,
        OuterMessage(
          protocolVersion: 1,
          status: PairingStatus.statusOk,
          pairingRequest: PairingRequest(
            serviceName: _serviceName,
            clientName: _clientName,
          ),
        ),
      );

      // Blocks until configuration_ack — the TV now shows the PIN.
      await _pairingStartedCompleters[deviceId]!.future;
      _emitState(deviceId, ConnectionState.connected);
    } catch (e) {
      _emitState(deviceId, ConnectionState.error);
      _cleanupDevice(deviceId);
      if (e is AndroidTvPairingFailedException ||
          e is AndroidTvConnectionException) {
        rethrow;
      }
      throw AndroidTvConnectionException(e.toString());
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
    _sendMessage(
      deviceId,
      OuterMessage(
        protocolVersion: 1,
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

    _cleanupDevice(deviceId);
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

  /// Closes the pairing socket (if open) and removes the stored server
  /// certificate so the device can be re-paired from scratch.
  @override
  Future<void> clearPairing({required String deviceId}) async {
    _cleanupDevice(deviceId);
    await _certStore.clearServerCert(_hostResolver(deviceId));
    _emitState(deviceId, ConnectionState.disconnected);
  }

  // Implemented in Task 9.
  @override
  Future<void> sendKey({required String deviceId, required String keyCode}) =>
      throw UnimplementedError('sendKey is implemented in Task 9');

  // Implemented in Task 9.
  @override
  Future<void> sendText({required String deviceId, required String text}) =>
      throw UnimplementedError('sendText is implemented in Task 9');

  @override
  Future<TvDeviceInfo> queryDeviceInfo({required String deviceId}) async =>
      const TvDeviceInfo();

  // ---------------------------------------------------------------------------
  // Pairing message handling
  // ---------------------------------------------------------------------------

  void _onData(String deviceId, List<int> data) {
    _pairingBuffers[deviceId]?.addAll(data);
    _drainBuffer(deviceId);
  }

  void _drainBuffer(String deviceId) {
    final buf = _pairingBuffers[deviceId];
    if (buf == null) return;

    while (true) {
      final varint = _tryDecodeVarint(buf);
      if (varint == null) return; // need more bytes for the length prefix

      final (msgLen, consumed) = varint;
      if (buf.length < consumed + msgLen) return; // need more bytes for payload

      final msgBytes = Uint8List.fromList(buf.sublist(consumed, consumed + msgLen));
      buf.removeRange(0, consumed + msgLen);

      try {
        _handleMessage(deviceId, OuterMessage.fromBuffer(msgBytes));
      } catch (e) {
        log('Android TV: message decode error: $e', name: 'android_tv_transport');
      }
    }
  }

  void _handleMessage(String deviceId, OuterMessage msg) {
    log(
      'Android TV pairing rx: ${msg.toDebugString()}',
      name: 'android_tv_transport',
    );

    if (msg.hasPairingRequestAck()) {
      // Step 3: inform the TV of supported encoding options.
      _sendMessage(
        deviceId,
        OuterMessage(
          protocolVersion: 1,
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
      _sendMessage(
        deviceId,
        OuterMessage(
          protocolVersion: 1,
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

  void _onSocketError(String deviceId, Object error) {
    log('Android TV socket error: $error', name: 'android_tv_transport');
    _failPending(deviceId, AndroidTvConnectionException(error.toString()));
    _cleanupDevice(deviceId);
    _emitState(deviceId, ConnectionState.error);
  }

  void _onSocketDone(String deviceId) {
    log('Android TV pairing socket closed', name: 'android_tv_transport');
    _failPending(
      deviceId,
      const AndroidTvConnectionException('Socket closed unexpectedly'),
    );
    _cleanupDevice(deviceId);
  }

  void _failPending(String deviceId, Object error) {
    final c1 = _pairingStartedCompleters[deviceId];
    if (c1 != null && !c1.isCompleted) c1.completeError(error);

    final c2 = _secretAckCompleters[deviceId];
    if (c2 != null && !c2.isCompleted) c2.completeError(error);
  }

  void _sendMessage(String deviceId, OuterMessage msg) {
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

  void _cleanupDevice(String deviceId) {
    _pairingSubs.remove(deviceId)?.cancel();
    _pairingSockets.remove(deviceId)?.destroy();
    _pairingBuffers.remove(deviceId);
    _serverCertDers.remove(deviceId);
    _serverRsa.remove(deviceId);
    _pairingStartedCompleters.remove(deviceId);
    _secretAckCompleters.remove(deviceId);
  }

  // ---------------------------------------------------------------------------
  // Secret computation
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
