import 'dart:developer' show log;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists SHA-256 fingerprints of Samsung TV TLS certificates (trust-on-first-use).
///
/// Samsung LAN TVs commonly use self-signed certificates. On first successful
/// WSS handshake to `host:port`, every certificate observed during that handshake
/// is pinned (some firmware presents a short chain and Dart may surface more
/// than one cert to [badCertificateCallback]). Later connects must present at
/// least one matching fingerprint or the connection fails (possible MITM, TV
/// cert rotation, or different device at the same address).
///
/// [clearEndpoint] is invoked when starting Samsung pairing so a stale pin
/// cannot block re-pairing after firmware changes or TLS behavior updates.
final class SamsungTlsTrustStore {
  SamsungTlsTrustStore._();

  static final SamsungTlsTrustStore instance = SamsungTlsTrustStore._();

  static const String _prefsPrefix = 'samsung_wss_tofu_v1_';

  final Map<String, Set<String>> _pinsByHostPort = <String, Set<String>>{};
  final Map<String, Set<String>> _pendingPinsByHostPort = <String, Set<String>>{};
  Future<void>? _ready;

  Future<void> ensureLoaded() => _ready ??= _loadFromPrefs();

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefsPrefix)) {
        continue;
      }
      final hostPort = key.substring(_prefsPrefix.length);
      final value = prefs.getString(key);
      if (value == null || value.trim().isEmpty) {
        continue;
      }
      final pins = value
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      if (pins.isNotEmpty) {
        _pinsByHostPort[hostPort] = pins;
      }
    }
  }

  static String _hostPortKey(String host, int port) =>
      '${host.toLowerCase()}:$port';

  /// Removes stored and in-flight pins for this endpoint (e.g. before pairing).
  Future<void> clearEndpoint(String host, int port) async {
    final key = _hostPortKey(host, port);
    _pinsByHostPort.remove(key);
    _pendingPinsByHostPort.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsPrefix$key');
  }

  /// Merges fingerprints collected during the last WSS attempt into the pinned
  /// set. Call after `ms.channel.connect` / ready on that socket.
  void commitPendingPins({required String host, required int port}) {
    final key = _hostPortKey(host, port);
    final pending = _pendingPinsByHostPort.remove(key);
    if (pending == null || pending.isEmpty) {
      return;
    }
    final merged = {...?_pinsByHostPort[key], ...pending};
    _pinsByHostPort[key] = merged;
    final serialized = merged.toList()..sort();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('$_prefsPrefix$key', serialized.join(','));
    });
  }

  /// Drops in-flight fingerprints when a WSS attempt fails before [commitPendingPins].
  void abandonPendingPins({required String host, required int port}) {
    _pendingPinsByHostPort.remove(_hostPortKey(host, port));
  }

  /// Returns true if [cert] matches a stored pin for [host]:[port], or if
  /// pins are not yet established for that endpoint (fingerprints are queued
  /// until [commitPendingPins] runs after a successful handshake).
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
    final pinned = _pinsByHostPort[key];
    if (pinned != null && pinned.isNotEmpty) {
      if (pinned.contains(fingerprint)) {
        return true;
      }
      log(
        'Samsung TLS: pin mismatch for $key (MITM, TV cert change, or different device at address)',
        name: 'samsung_transport',
      );
      return false;
    }
    _pendingPinsByHostPort.putIfAbsent(key, () => <String>{}).add(fingerprint);
    return true;
  }
}
