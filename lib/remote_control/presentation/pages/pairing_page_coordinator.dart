import 'package:one_remote/app/message_handler.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/result.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Coordinates pairing and persistence steps for `PairingPage`.
class PairingPageCoordinator {
  const PairingPageCoordinator({
    required RemoteCommandService commandService,
    required DeviceRepository deviceRepository,
  }) : _commandService = commandService,
       _deviceRepository = deviceRepository;

  final RemoteCommandService _commandService;
  final DeviceRepository _deviceRepository;

  Future<PairingAttemptResult> pairSelectedDevice({
    required TvDevice device,
    String? manualIpToSave,
    required Future<String?> Function(String pairingMessage) promptHisensePin,
    required void Function(String retryMessage) onHisensePinRejected,
  }) async {
    final pairingResult = await _commandService.preparePairing(device: device);
    if (!pairingResult.isSuccess) {
      final didCompleteViaPin = await _attemptHisensePinFallback(
        device: device,
        pairingMessage: MessageHandler.sanitize(pairingResult),
        promptHisensePin: promptHisensePin,
        onHisensePinRejected: onHisensePinRejected,
      );
      if (!didCompleteViaPin) {
        return PairingAttemptResult.failure(MessageHandler.sanitize(pairingResult));
      }
    }

    if (manualIpToSave != null && manualIpToSave.isNotEmpty) {
      await _deviceRepository.saveRecentManualIp(manualIpToSave);
    }
    final pairedAt = DateTime.now();
    await _deviceRepository.saveDevice(device);
    await _deviceRepository.setLastUsedDevice(device.id);
    await _deviceRepository.setLastSuccessfulPairingAt(
      deviceId: device.id,
      timestamp: pairedAt,
    );
    return const PairingAttemptResult.success();
  }

  Future<bool> _attemptHisensePinFallback({
    required TvDevice device,
    required String pairingMessage,
    required Future<String?> Function(String pairingMessage) promptHisensePin,
    required void Function(String retryMessage) onHisensePinRejected,
  }) async {
    if (device.brand != TvBrand.hisense) {
      return false;
    }

    while (true) {
      final pin = await promptHisensePin(pairingMessage);
      if (pin == null) {
        return false;
      }

      final submitResult = await _commandService.submitPairingCode(
        device: device,
        fourDigitPin: pin,
      );
      if (submitResult.isSuccess) {
        return true;
      }
      onHisensePinRejected(MessageHandler.sanitize(submitResult));
    }
  }
}

final class PairingAttemptResult extends Result {
  const PairingAttemptResult._({
    required bool isSuccess,
    required String message,
  }) : _isSuccess = isSuccess,
       super(message: message);

  const PairingAttemptResult.success() : this._(isSuccess: true, message: '');

  const PairingAttemptResult.failure(String message)
    : this._(isSuccess: false, message: message);

  final bool _isSuccess;

  @override
  bool get isSuccess => _isSuccess;
}
