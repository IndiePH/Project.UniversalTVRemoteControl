class LgPairingTimeoutException implements Exception {
  const LgPairingTimeoutException(this.message);
  final String message;
  @override
  String toString() => 'LgPairingTimeoutException: $message';
}

class LgPairingRejectedException implements Exception {
  const LgPairingRejectedException(this.message);
  final String message;
  @override
  String toString() => 'LgPairingRejectedException: $message';
}

class LgPairingSessionExpiredException implements Exception {
  const LgPairingSessionExpiredException(this.message);
  final String message;
  @override
  String toString() => 'LgPairingSessionExpiredException: $message';
}
