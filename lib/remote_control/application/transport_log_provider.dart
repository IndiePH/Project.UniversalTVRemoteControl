import 'package:one_remote/remote_control/application/transport_log_reader.dart';

/// Opt-in interface for adapters that can surface transport logs.
abstract interface class TransportLogProvider {
  TransportLogReader get transportLogReader;
}
