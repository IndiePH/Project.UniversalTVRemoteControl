import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Application port that resolves the correct [TransportLogReader] for a device.
abstract interface class TransportLogReaderProvider {
  TransportLogReader readerForDevice(TvDevice device);
}

/// No-op fallback used when no provider is configured.
final class NoopTransportLogReaderProvider implements TransportLogReaderProvider {
  const NoopTransportLogReaderProvider();

  @override
  TransportLogReader readerForDevice(TvDevice device) => const NoopTransportLogReader();
}
