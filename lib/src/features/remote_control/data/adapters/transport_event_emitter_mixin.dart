import 'dart:async';

import 'package:one_remote/src/features/remote_control/data/adapters/transport_event.dart';
import 'package:one_remote/src/features/remote_control/data/adapters/transport_event_source.dart';

/// Shared broadcast emitter for transport event streams.
mixin TransportEventEmitterMixin implements TransportEventSource {
  final StreamController<TransportEvent> _eventsController =
      StreamController<TransportEvent>.broadcast();

  @override
  Stream<TransportEvent> get events => _eventsController.stream;

  void emitTransportEvent(TransportEvent event) {
    if (_eventsController.isClosed) {
      return;
    }
    _eventsController.add(event);
  }
}
