class AndroidTvPairingFailedException implements Exception {
  const AndroidTvPairingFailedException([this.message]);

  final String? message;

  @override
  String toString() =>
      'AndroidTvPairingFailedException: ${message ?? "Pairing failed"}';
}

class AndroidTvConnectionException implements Exception {
  const AndroidTvConnectionException([this.message]);

  final String? message;

  @override
  String toString() =>
      'AndroidTvConnectionException: ${message ?? "Connection failed"}';
}
