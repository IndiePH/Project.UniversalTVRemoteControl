enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  unauthorized;

  /// Transient loss should be retried; user denial / pairing reject should not.
  bool get shouldAutoReconnect => this == disconnected || this == error;
}
