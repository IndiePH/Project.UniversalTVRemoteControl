import 'dart:async';

import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_authorization.dart';

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
/// Does not own sockets; the transport client resets connections when
/// [handleDecoded] returns [SamsungPairingFrameOutcome.unauthorized].
class SamsungPairingTokenStore {
  final Map<String, String> _tokenByHost = <String, String>{};
  final Map<String, Set<Completer<void>>> _pendingPairingByHost =
      <String, Set<Completer<void>>>{};

  String? tokenForHost(String host) => _tokenByHost[host];

  void setTokenForHost(String host, String token) {
    _tokenByHost[host] = token;
  }

  void clearTokenForHost(String host) {
    _tokenByHost.remove(host);
  }

  bool hasNonEmptyToken(String host) =>
      (_tokenByHost[host] ?? '').trim().isNotEmpty;

  String trimmedTokenForHost(String host) =>
      _tokenByHost[host]?.trim() ?? '';

  void registerPendingApproval(String host, Completer<void> completer) {
    _pendingPairingByHost.putIfAbsent(host, () => <Completer<void>>{}).add(
          completer,
        );
  }

  void cancelPendingApprovals(String host) {
    _failPendingPairingApprovals(
      host: host,
      error: StateError('Pairing cancelled'),
    );
  }

  void unregisterPendingApproval(String host, Completer<void> completer) {
    final current = _pendingPairingByHost[host];
    current?.remove(completer);
    if (current != null && current.isEmpty) {
      _pendingPairingByHost.remove(host);
    }
  }

  /// Inspects `ms.channel.connect` data for a token, or fails waiters on
  /// unauthorized-style frames.
  SamsungPairingFrameOutcome handleDecoded(
    String host,
    Map<String, dynamic>? decoded,
  ) {
    if (decoded == null) {
      return SamsungPairingFrameOutcome.ignored;
    }
    if (_isUnauthorizedFrame(decoded)) {
      _failPendingPairingApprovals(
        host: host,
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
      _tokenByHost[host] = token.trim();
      _completePendingPairingApprovals(host);
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
}
