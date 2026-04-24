/// Common transport event payload emitted by adapter transport clients.
final class TransportEvent {
  const TransportEvent({
    required this.transport,
    required this.deviceId,
    required this.type,
    this.message,
  });

  final String transport;
  final String deviceId;
  final String type;
  final String? message;
}
