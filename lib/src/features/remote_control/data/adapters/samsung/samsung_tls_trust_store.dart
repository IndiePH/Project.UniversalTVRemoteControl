import 'dart:developer' show log;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists SHA-256 fingerprints of Samsung TV TLS certificates (trust-on-first-use).
///
/// Samsung LAN TVs commonly use self-signed certificates. On first successful
/// handshake to `host:port`, the observed cert is pinned. Later connects must
/// present the same cert or the connection fails (possible MITM or TV cert
/// rotation after firmware—clear app data or add a future "forget TV" action).
final class SamsungTlsTrustStore {
  SamsungTlsTrustStore._();

  static final SamsungTlsTrustStore instance = SamsungTlsTrustStore._();

  static const String _prefsPrefix = 'samsung_wss_tofu_v1_';

  final Map<String, String> _pinByHostPort = <String, String>{};
  Future<void>? _ready;

  Future<void> ensureLoaded() =>
      _ready ??= _loadFromPrefs();

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefsPrefix)) continue;
      final hostPort = key.substring(_prefsPrefix.length);
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        _pinByHostPort[hostPort] = value;
      }
    }
  }

  /// Returns true only if [cert] matches the stored pin for [host]:[port], or
  /// if this is the first observation for that endpoint (pin is then saved).
  bool verifyServerCertificate({
    required String host,
    required int port,
    required X509Certificate cert,
  }) {
    final der = cert.der;
    if (der.isEmpty) {
      log(
        'Samsung TLS: empty certificate DER for $host:$port',
        name: 'samsung_transport',
      );
      return false;
    }
    final fingerprint = sha256.convert(der).toString();
    final key = _hostPortKey(host, port);
    final existing = _pinByHostPort[key];
    if (existing == null) {
      _pinByHostPort[key] = fingerprint;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('$_prefsPrefix$key', fingerprint);
      });
      return true;
    }
    if (existing == fingerprint) {
      return true;
    }
    log(
      'Samsung TLS: pin mismatch for $key (MITM, TV cert change, or different device at address)',
      name: 'samsung_transport',
    );
    return false;
  }

  static String _hostPortKey(String host, int port) => '${host.toLowerCase()}:$port';
}
