import 'dart:async';

import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_authorization.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_gateway.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_host_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_secure_host_scoped_secret_persistence.dart';

/// Outcome of inspecting an inbound JSON frame for pairing / token fields.
enum SamsungPairingFrameOutcome {
  /// Frame did not affect pairing state.
  ignored,

  /// TV reported unauthorized; pending approval completers were failed.
  unauthorized,

  /// Token was stored and pending approval completers were completed.
  tokenStored,
}

/// Host-keyed pairing token and in-flight TV-approval waiters.
///
/// Tokens are cached in memory and persisted locally per host (encrypted on
/// mobile). Cleared on [clearTokenForHost] / transport [clearPairing].
///
/// Phase 3: when a stable id is known for a host (via [DeviceIdentityRegistry]),
/// the token is persisted under that stable id through [DeviceScopedSecretGateway]
/// so it survives LAN IP changes. Legacy host-keyed entries are still read as a
/// fallback for devices paired before stable ids were captured. The in-memory
/// cache remains host-keyed because it is session-scoped and indexed by the
/// host the transport client addresses.
class SamsungPairingTokenStore {
  SamsungPairingTokenStore({
    LegacyHostScopedSecretPersistence? persistence,
    DeviceScopedSecretPersistence? devicePersistence,
    DeviceIdentityRegistry? identityRegistry,
  }) : _gateway = DeviceScopedSecretGateway(
          hostPersistence:
              persistence ??
              LegacySecureHostScopedSecretPersistence(keyPrefix: 'samsung_remote_token_'),
          devicePersistence: devicePersistence,
          identityRegistry: identityRegistry,
        );

  final DeviceScopedSecretGateway _gateway;
  final Map<String, String> _tokenByHost = <String, String>{};
  final Set<String> _loadedHosts = <String>{};
  final Map<String, Set<Completer<void>>> _pendingPairingByHost =
      <String, Set<Completer<void>>>{};

  /// Loads the persisted token for [host] into the in-memory cache.
  Future<void> ensureHostLoaded(String host) async {
    final normalized = _normalizeHost(host);
    if (_loadedHosts.contains(normalized)) {
      return;
    }
    _loadedHosts.add(normalized);
    final stored = await _gateway.read(normalized);
    if (stored != null && stored.trim().isNotEmpty) {
      _tokenByHost[normalized] = stored.trim();
    }
  }

  String? tokenForHost(String host) => _tokenByHost[_normalizeHost(host)];

  Future<void> setTokenForHost(String host, String token) async {
    final normalized = _normalizeHost(host);
    final trimmed = token.trim();
    _tokenByHost[normalized] = trimmed;
    _loadedHosts.add(normalized);
    await _gateway.write(normalized, trimmed);
  }

  Future<void> clearTokenForHost(String host) async {
    final normalized = _normalizeHost(host);
    _tokenByHost.remove(normalized);
    _loadedHosts.remove(normalized);
    await _gateway.delete(normalized);
  }

  bool hasNonEmptyToken(String host) =>
      (_tokenByHost[_normalizeHost(host)] ?? '').trim().isNotEmpty;

  String trimmedTokenForHost(String host) =>
      _tokenByHost[_normalizeHost(host)]?.trim() ?? '';

  void registerPendingApproval(String host, Completer<void> completer) {
    final normalized = _normalizeHost(host);
    _pendingPairingByHost
        .putIfAbsent(normalized, () => <Completer<void>>{})
        .add(completer);
  }

  void cancelPendingApprovals(String host) {
    _failPendingPairingApprovals(
      host: _normalizeHost(host),
      error: StateError('Pairing cancelled'),
    );
  }

  void unregisterPendingApproval(String host, Completer<void> completer) {
    final normalized = _normalizeHost(host);
    final current = _pendingPairingByHost[normalized];
    current?.remove(completer);
    if (current != null && current.isEmpty) {
      _pendingPairingByHost.remove(normalized);
    }
  }

  /// Inspects `ms.channel.connect` data for a token, or fails waiters on
  /// unauthorized-style frames.
  SamsungPairingFrameOutcome handleDecoded(
    String host,
    Map<String, dynamic>? decoded,
  ) {
    final normalized = _normalizeHost(host);
    if (decoded == null) {
      return SamsungPairingFrameOutcome.ignored;
    }
    if (_isUnauthorizedFrame(decoded)) {
      _failPendingPairingApprovals(
        host: normalized,
        error: const SamsungTransportAuthorizationException(
          'Samsung TV rejected remote-control authorization.',
        ),
      );
      return SamsungPairingFrameOutcome.unauthorized;
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return SamsungPairingFrameOutcome.ignored;
    }
    final token = data['token'];
    if (token is String && token.trim().isNotEmpty) {
      final trimmed = token.trim();
      _tokenByHost[normalized] = trimmed;
      _loadedHosts.add(normalized);
      unawaited(_gateway.write(normalized, trimmed));
      _completePendingPairingApprovals(normalized);
      return SamsungPairingFrameOutcome.tokenStored;
    }
    return SamsungPairingFrameOutcome.ignored;
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

  static String _normalizeHost(String host) => host.trim().toLowerCase();
}
