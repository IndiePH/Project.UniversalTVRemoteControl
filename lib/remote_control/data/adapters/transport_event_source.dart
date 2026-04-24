import 'package:one_remote/remote_control/data/adapters/transport_event.dart';

/// Required event stream for transport diagnostics/observers.
abstract interface class TransportEventSource {
  Stream<TransportEvent> get events;
}
