abstract class SamsungTransportClient {
  Future<void> connect({required String deviceId});

  Future<void> requestPairingApproval({
    required String deviceId,
    required String triggerKeyCode,
    Duration approvalTimeout = const Duration(seconds: 45),
  });

  Future<void> sendKey({required String deviceId, required String keyCode});

  Future<void> sendText({required String deviceId, required String text});
}
