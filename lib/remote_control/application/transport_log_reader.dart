/// Application-layer port for optional transport-log access.
abstract class TransportLogReader {
  Future<String?> readLatestLogForSharing();
}

/// Default no-op reader used when log access is not configured.
final class NoopTransportLogReader implements TransportLogReader {
  const NoopTransportLogReader();

  @override
  Future<String?> readLatestLogForSharing() async => null;
}
