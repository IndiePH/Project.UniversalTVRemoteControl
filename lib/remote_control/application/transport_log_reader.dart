/// Application-layer port for optional transport-log access.
abstract class TransportLogReader {
  Future<String?> readLatestSamsungLogForSharing();
}

/// Default no-op reader used when log access is not configured.
final class NoopTransportLogReader implements TransportLogReader {
  const NoopTransportLogReader();

  @override
  Future<String?> readLatestSamsungLogForSharing() async => null;
}
