import 'dart:io';

/// Classifies uncaught zone errors before Crashlytics records them.
///
/// LAN TV sockets reset often (peer sleep, Wi-Fi blip, RST). Those are
/// expected transport failures, not application crashes.
abstract final class UnhandledZoneError {
  /// Whether [error] should be recorded as a Crashlytics fatal.
  static bool isFatal(Object error) => error is! SocketException;
}
