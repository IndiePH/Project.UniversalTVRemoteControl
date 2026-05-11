/// Captures raw bytes and handshake event sequences for surfacing in
/// debug-mode error messages. Injected by the DI config; null in production.
class AndroidTvHandshakeTracer {
  final Map<String, List<int>> _rawBytes = {};
  final Map<String, List<String>> _events = {};

  void init(String deviceId) {
    _rawBytes[deviceId] = [];
    _events[deviceId] = [];
  }

  void recordBytes(String deviceId, List<int> data) {
    final buf = _rawBytes[deviceId];
    if (buf != null && buf.length < 64) buf.addAll(data.take(64 - buf.length));
  }

  void recordEvent(String deviceId, String event) =>
      _events[deviceId]?.add(event);

  String summary(String deviceId) {
    final rx = _rawBytes[deviceId] ?? [];
    final events = _events[deviceId] ?? [];
    final rawHex = rx.isEmpty
        ? 'TV sent 0 bytes'
        : 'TV sent ${rx.length}B: ${rx.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}${rx.length > 32 ? '…' : ''}';
    final evtStr = events.isEmpty ? 'no events' : events.join(' → ');
    return '$rawHex; events: $evtStr';
  }

  void dispose(String deviceId) {
    _rawBytes.remove(deviceId);
    _events.remove(deviceId);
  }
}
