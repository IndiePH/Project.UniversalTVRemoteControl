class PinRequiredException implements Exception {
  const PinRequiredException(this.message);

  final String message;

  @override
  String toString() => 'PinRequiredException: $message';
}
