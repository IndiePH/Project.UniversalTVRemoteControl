/// Thrown when the TV session is fine but the current app or UI state does not
/// accept remote IME text injection (common for some streaming or custom UIs).
class TextInputCompatibilityException implements Exception {
  TextInputCompatibilityException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}
