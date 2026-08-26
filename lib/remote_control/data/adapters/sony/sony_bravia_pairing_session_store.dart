import 'dart:convert';

import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_gateway.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_host_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_secure_host_scoped_secret_persistence.dart';

/// The two pieces of state BRAVIA's PIN-mode session needs on every request
/// after `actRegister` succeeds: the original Basic-Auth header (must be
/// resent — the cookie alone is not sufficient, confirmed via `pybravia`'s
/// source) and the session cookie the TV returned.
class SonyBraviaSession {
  const SonyBraviaSession({required this.authHeader, required this.cookie});

  final String authHeader;
  final String cookie;

  String encode() => jsonEncode({'authHeader': authHeader, 'cookie': cookie});

  static SonyBraviaSession decode(String value) {
    final map = jsonDecode(value) as Map<String, dynamic>;
    return SonyBraviaSession(
      authHeader: map['authHeader'] as String,
      cookie: map['cookie'] as String,
    );
  }
}

/// Persists a Sony BRAVIA IP Control session per TV host.
///
/// Follows the same [DeviceScopedSecretGateway]-over-[LegacyHostScopedSecretPersistence]
/// shape every other brand's pairing store already uses (e.g.
/// `SamsungPairingTokenStore`, `LgPairingKeyStore`) — a new brand, but not a
/// new persistence pattern.
class SonyBraviaPairingSessionStore {
  SonyBraviaPairingSessionStore({
    LegacyHostScopedSecretPersistence? persistence,
    DeviceScopedSecretPersistence? devicePersistence,
    DeviceIdentityRegistry? identityRegistry,
  }) : _gateway = DeviceScopedSecretGateway(
         hostPersistence:
             persistence ??
             LegacySecureHostScopedSecretPersistence(
               keyPrefix: 'sony_bravia_session_',
             ),
         devicePersistence: devicePersistence,
         identityRegistry: identityRegistry,
       );

  final DeviceScopedSecretGateway _gateway;

  Future<SonyBraviaSession?> sessionForHost(String host) async {
    final stored = await _gateway.read(_normalizeHost(host));
    if (stored == null || stored.isEmpty) {
      return null;
    }
    return SonyBraviaSession.decode(stored);
  }

  Future<void> setSessionForHost(String host, SonyBraviaSession session) =>
      _gateway.write(_normalizeHost(host), session.encode());

  Future<void> clearHost(String host) => _gateway.delete(_normalizeHost(host));

  static String _normalizeHost(String host) => host.trim().toLowerCase();
}
