import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:one_remote/remote_control/application/pin_required_exception.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_bravia_pairing_session_store.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_bravia_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/remote_control/data/adapters/transport_event_emitter_mixin.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real implementation of [SonyBraviaTransportClient] — BRAVIA IP Control
/// (REST/JSON-RPC over HTTP, port 80), PIN-mode auth only. See
/// `guide-tv-remote-protocols.md`'s "Sony BRAVIA IP Control" section for the
/// protocol details this implements.
class SonyBraviaHttpTransportClient
    with TransportEventEmitterMixin
    implements SonyBraviaTransportClient {
  SonyBraviaHttpTransportClient({
    required this._sessionStore,
    String Function(String deviceId)? hostResolver,
    this._requestTimeout = const Duration(seconds: 4),
  }) : _hostResolver = hostResolver ?? _defaultHostResolver;

  final SonyBraviaPairingSessionStore _sessionStore;
  final String Function(String deviceId) _hostResolver;
  final Duration _requestTimeout;

  final Map<String, StreamController<ConnectionState>> _connectionControllers =
      <String, StreamController<ConnectionState>>{};
  final Map<String, ConnectionState> _lastConnectionStates =
      <String, ConnectionState>{};

  /// Per-host cache of the device's own IRCC command-name -> base64-code
  /// table, fetched once via `getRemoteControllerInfo`. Never persisted —
  /// cheap to refetch on reconnect, and Sony's codes don't change firmware
  /// to firmware within one boot session.
  final Map<String, Map<String, String>> _remoteCommandCache =
      <String, Map<String, String>>{};

  /// Per-host cache of the device's own installed-app title -> launch-uri
  /// table, fetched once via `getApplicationList`. Host-scoped for the same
  /// reason as [_remoteCommandCache] — different physical TVs can have
  /// different apps installed under different URIs.
  final Map<String, Map<String, String>> _installedAppsCache =
      <String, Map<String, String>>{};

  String? _cachedClientId;

  static final RegExp _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');
  static const String _clientIdPrefsKey = 'sony_bravia_client_id';
  static const String _nickname = 'One Remote';

  @override
  Future<void> connect({required String deviceId}) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Sony BRAVIA host missing for deviceId: $deviceId');
    }
    final session = await _sessionStore.sessionForHost(host);
    if (session == null) {
      throw const PinRequiredException(
        'Sony BRAVIA TV requires PIN pairing (actRegister).',
      );
    }
    _emitConnectionState(deviceId, ConnectionState.connected);
    emitTransportEvent(
      TransportEvent(
        transport: 'sony_bravia',
        deviceId: deviceId,
        type: 'connected',
      ),
    );
  }

  @override
  Future<void> probe(String host) async {
    final socket = await Socket.connect(
      host,
      80,
      timeout: _requestTimeout,
    );
    socket.destroy();
  }

  @override
  Future<void> registerPin({required String deviceId, String? pin}) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Sony BRAVIA host missing for deviceId: $deviceId');
    }
    final clientId = await _clientId();
    final authHeader =
        'Basic ${base64Encode(utf8.encode(':${pin ?? ''}'))}';
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse('http://$host/sony/accessControl'))
          .timeout(_requestTimeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, authHeader);
      request.write(
        jsonEncode({
          'method': 'actRegister',
          'id': 1,
          'version': '1.0',
          'params': [
            {'clientid': clientId, 'nickname': _nickname, 'level': 'private'},
            [
              {'value': 'yes', 'function': 'WOL'},
            ],
          ],
        }),
      );
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Expected on the first, no-PIN call — this is what makes the TV
        // display an on-screen PIN. Also the outcome for a wrong PIN.
        await response.drain<void>().catchError((_) {});
        throw PinRequiredException(
          'Sony BRAVIA actRegister returned ${response.statusCode}.',
        );
      }
      final rawCookies = response.headers[HttpHeaders.setCookieHeader];
      await response.drain<void>().catchError((_) {});
      if (rawCookies == null || rawCookies.isEmpty) {
        throw StateError(
          'Sony BRAVIA actRegister succeeded without a session cookie.',
        );
      }
      // Set-Cookie values carry attributes (Path, HttpOnly, Expires, ...)
      // after the first `;` — a Cookie *request* header must only ever
      // contain `name=value` pairs, never those attributes.
      final cookieHeaderValue = rawCookies
          .map(Cookie.fromSetCookieValue)
          .map((cookie) => '${cookie.name}=${cookie.value}')
          .join('; ');
      await _sessionStore.setSessionForHost(
        host,
        SonyBraviaSession(authHeader: authHeader, cookie: cookieHeaderValue),
      );
      _emitConnectionState(deviceId, ConnectionState.connected);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  }) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Sony BRAVIA host missing for deviceId: $deviceId');
    }
    final session = await _sessionStore.sessionForHost(host);
    if (session == null) {
      throw const PinRequiredException(
        'Sony BRAVIA TV requires PIN pairing (actRegister).',
      );
    }
    final commandMap = await _remoteCommandMapFor(host, session);
    final code = commandMap[keyCode];
    if (code == null) {
      throw UnsupportedError(
        'Sony BRAVIA TV does not report an IRCC code named "$keyCode".',
      );
    }
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse('http://$host/sony/IRCC'))
          .timeout(_requestTimeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'text/xml; charset=UTF-8');
      request.headers.set(
        'SOAPACTION',
        '"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC"',
      );
      _attachSession(request, session);
      request.write(
        '<?xml version="1.0"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body>'
        '<u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">'
        '<IRCCCode>$code</IRCCCode>'
        '</u:X_SendIRCC>'
        '</s:Body>'
        '</s:Envelope>',
      );
      final response = await request.close().timeout(_requestTimeout);
      await response.drain<void>().catchError((_) {});
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Sony BRAVIA IRCC send failed (${response.statusCode})',
        );
      }
      emitTransportEvent(
        TransportEvent(
          transport: 'sony_bravia',
          deviceId: deviceId,
          type: 'key_sent',
          message: keyCode,
        ),
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required String deviceId}) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) return null;
    final session = await _sessionStore.sessionForHost(host);
    if (session == null) return const TvDeviceInfo();
    try {
      final result = await _restCall(
        host: host,
        session: session,
        service: 'system',
        method: 'getSystemInformation',
      );
      final info = result is List && result.isNotEmpty
          ? result.first as Map<String, dynamic>
          : null;
      return TvDeviceInfo(
        modelIdentifier: info?['model'] as String? ?? 'sony_bravia_ip_control',
        firmwareVersion: info?['generation'] as String?,
      );
    } catch (_) {
      return const TvDeviceInfo(modelIdentifier: 'sony_bravia_ip_control');
    }
  }

  @override
  Future<void> clearPairing({required String deviceId}) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isNotEmpty) {
      await _sessionStore.clearHost(host);
      _remoteCommandCache.remove(host);
      _installedAppsCache.remove(host);
    }
    _emitConnectionState(deviceId, ConnectionState.disconnected);
  }

  @override
  Future<String?> resolveAppUri({
    required String deviceId,
    required String titleContains,
  }) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) return null;
    final session = await _sessionStore.sessionForHost(host);
    if (session == null) return null;
    final apps = await _installedAppsFor(host, session);
    final needle = titleContains.toLowerCase();
    // Exact match first — a substring-only match risks a near-namesake app
    // (e.g. an installed "YouTube Kids") shadowing the intended one, since
    // map iteration follows the TV's own reported order, not alphabetical.
    for (final entry in apps.entries) {
      if (entry.key.toLowerCase() == needle) {
        return entry.value;
      }
    }
    for (final entry in apps.entries) {
      if (entry.key.toLowerCase().contains(needle)) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  Future<void> launchApp({
    required String deviceId,
    required String uri,
  }) async {
    final host = _hostResolver(deviceId).trim();
    if (host.isEmpty) {
      throw StateError('Sony BRAVIA host missing for deviceId: $deviceId');
    }
    final session = await _sessionStore.sessionForHost(host);
    if (session == null) {
      throw const PinRequiredException(
        'Sony BRAVIA TV requires PIN pairing (actRegister).',
      );
    }
    await _restCall(
      host: host,
      session: session,
      service: 'appControl',
      method: 'setActiveApp',
      params: [
        {'uri': uri},
      ],
    );
    emitTransportEvent(
      TransportEvent(
        transport: 'sony_bravia',
        deviceId: deviceId,
        type: 'app_launched',
        message: uri,
      ),
    );
  }

  Future<Map<String, String>> _installedAppsFor(
    String host,
    SonyBraviaSession session,
  ) async {
    final cached = _installedAppsCache[host];
    if (cached != null) {
      return cached;
    }
    final result = await _restCall(
      host: host,
      session: session,
      service: 'appControl',
      method: 'getApplicationList',
    );
    final entries = result is List && result.isNotEmpty
        ? result.first as List<dynamic>
        : const <dynamic>[];
    final map = <String, String>{
      for (final entry in entries.cast<Map<String, dynamic>>())
        if (entry['title'] is String && entry['uri'] is String)
          entry['title'] as String: entry['uri'] as String,
    };
    _installedAppsCache[host] = map;
    return map;
  }

  @override
  Stream<ConnectionState> watchConnectionState(String deviceId) =>
      _controllerFor(deviceId).stream;

  Future<Map<String, String>> _remoteCommandMapFor(
    String host,
    SonyBraviaSession session,
  ) async {
    final cached = _remoteCommandCache[host];
    if (cached != null) {
      return cached;
    }
    final result = await _restCall(
      host: host,
      session: session,
      service: 'system',
      method: 'getRemoteControllerInfo',
    );
    final entries = result is List && result.length > 1
        ? result[1] as List<dynamic>
        : const <dynamic>[];
    final map = <String, String>{
      for (final entry in entries.cast<Map<String, dynamic>>())
        if (entry['name'] is String && entry['value'] is String)
          entry['name'] as String: entry['value'] as String,
    };
    _remoteCommandCache[host] = map;
    return map;
  }

  Future<dynamic> _restCall({
    required String host,
    required SonyBraviaSession session,
    required String service,
    required String method,
    List<Object?> params = const [],
  }) async {
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse('http://$host/sony/$service'))
          .timeout(_requestTimeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      _attachSession(request, session);
      request.write(
        jsonEncode({
          'method': method,
          'id': 1,
          'version': '1.0',
          'params': params,
        }),
      );
      final response = await request.close().timeout(_requestTimeout);
      final body = utf8.decode(
        await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b)),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Sony BRAVIA $service.$method failed (${response.statusCode})',
        );
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['result'];
    } finally {
      client.close(force: true);
    }
  }

  void _attachSession(HttpClientRequest request, SonyBraviaSession session) {
    request.headers.set(HttpHeaders.authorizationHeader, session.authHeader);
    request.headers.set(HttpHeaders.cookieHeader, session.cookie);
  }

  Future<String> _clientId() async {
    final cached = _cachedClientId;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_clientIdPrefsKey);
    if (id == null || id.isEmpty) {
      id = _generateClientId();
      await prefs.setString(_clientIdPrefsKey, id);
    }
    _cachedClientId = id;
    return id;
  }

  static String _generateClientId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  StreamController<ConnectionState> _controllerFor(String deviceId) {
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
    final controller = _connectionControllers[deviceId];
    if (controller != null && !controller.isClosed) {
      controller.add(state);
    }
  }

  static String _defaultHostResolver(String deviceId) {
    final match = _ipv4.firstMatch(deviceId);
    return match?.group(1) ?? '';
  }
}
