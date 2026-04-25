import 'package:one_remote/app/message_handler.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/result.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
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
    required Future<String?> Function(String pairingMessage) promptPin,
    required void Function(String retryMessage) onPinRejected,
  }) async {
    final pairingResult = await _commandService.preparePairing(device: device);
    if (!pairingResult.isSuccess) {
      if (!device.capabilities.contains(DeviceCapability.pinPairing)) {
        return PairingAttemptResult.failure(MessageHandler.sanitize(pairingResult));
      }
      final pairingMessage = MessageHandler.sanitize(pairingResult);
      final paired = await _attemptPinPairing(
        device: device,
        pairingMessage: pairingMessage,
        promptPin: promptPin,
        onPinRejected: onPinRejected,
      );
      if (!paired) {
        return PairingAttemptResult.failure(pairingMessage);
      }
    }

    if (manualIpToSave != null && manualIpToSave.isNotEmpty) {
      await _deviceRepository.saveRecentManualIp(manualIpToSave);
    }
    final pairedAt = DateTime.now();
    final deviceToSave = pairingResult.device ?? device;
    await _deviceRepository.saveDevice(deviceToSave);
    await _deviceRepository.setLastUsedDevice(deviceToSave.id);
    await _deviceRepository.setLastSuccessfulPairingAt(
      deviceId: device.id,
      timestamp: pairedAt,
    );
    return PairingAttemptResult.success();
  }

  Future<bool> _attemptPinPairing({
    required TvDevice device,
    required String pairingMessage,
    required Future<String?> Function(String) promptPin,
    required void Function(String) onPinRejected,
  }) async {
    while (true) {
      final pin = await promptPin(pairingMessage);
      if (pin == null) return false;
      final submitResult = await _commandService.submitPairingCode(
        device: device,
        fourDigitPin: pin,
      );
      if (submitResult.isSuccess) return true;
      onPinRejected(MessageHandler.sanitize(submitResult));
    }
  }
}

enum PairingOutcome { success, failure }

final class PairingAttemptResult extends Result {
  PairingAttemptResult.success() : super(outcome: PairingOutcome.success.name,message: '');
  PairingAttemptResult.failure(String message)
    : super(outcome: PairingOutcome.failure.name,message: message);

  PairingOutcome getOutcome() => PairingOutcome.values.byName(outcome);

  @override
  bool get isSuccess => getOutcome() == PairingOutcome.success;
}
