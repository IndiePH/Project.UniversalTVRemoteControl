import 'dart:async';

import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_authorization.dart';

/// Completes a connect-time [Completer] when the TV emits channel-ready events.
abstract final class SamsungWsHandshake {
  static void tryComplete({
    required Map<String, dynamic>? decoded,
    required Completer<void>? handshakeCompleter,
  }) {
    if (handshakeCompleter == null ||
        handshakeCompleter.isCompleted ||
        decoded == null) {
      return;
    }
    final event = decoded['event'];
    if (event is! String) {
      return;
    }
    if (event == 'ms.channel.connect' || event == 'ms.channel.ready') {
      handshakeCompleter.complete();
      return;
    }
    if (event == 'ms.channel.unauthorized') {
      handshakeCompleter.completeError(
        const SamsungTransportAuthorizationException(
          'Samsung TV rejected remote-control authorization.',
        ),
      );
      return;
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.toLowerCase().contains('unauthorized')) {
        handshakeCompleter.completeError(
          const SamsungTransportAuthorizationException(
            'Samsung TV rejected remote-control authorization.',
          ),
        );
      }
    }
  }
}
