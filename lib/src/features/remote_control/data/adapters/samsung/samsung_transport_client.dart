abstract class SamsungTransportClient {
  Future<void> connect({
    required String deviceId,
  });

  Future<void> sendKey({
    required String deviceId,
    required String keyCode,
  });

  Future<void> sendText({
    required String deviceId,
    required String text,
  });
}
