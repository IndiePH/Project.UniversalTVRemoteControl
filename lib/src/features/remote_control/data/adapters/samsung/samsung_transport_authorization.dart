/// Thrown when the TV rejects remote-control authorization on the WSS channel.
final class SamsungTransportAuthorizationException implements Exception {
  const SamsungTransportAuthorizationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Shared helpers for interpreting Samsung transport authorization failures.
abstract final class SamsungTransportAuthorization {
  static bool isAuthorizationError(Object error) {
    if (error is SamsungTransportAuthorizationException) {
      return true;
    }
    return error.toString().toLowerCase().contains('authorization');
  }
}
