import 'package:one_remote/src/features/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/samsung/samsung_transport_file_logger.dart';

/// Data-layer adapter for transport log sharing.
final class SamsungTransportLogReader implements TransportLogReader {
  const SamsungTransportLogReader();

  @override
  Future<String?> readLatestSamsungLogForSharing() {
    return SamsungTransportFileLogger.readLatestLogForSharing();
  }
}
