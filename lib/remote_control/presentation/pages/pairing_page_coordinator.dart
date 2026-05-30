import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/app/message_handler.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/result.dart';
import 'package:one_remote/remote_control/domain/models/pin_format.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Coordinates pairing and persistence steps for `PairingPage`.
class PairingPageCoordinator {
  const PairingPageCoordinator({
    required this._commandService,
    required this._deviceRepository,
    this._diagnosticsRecorder,
  });

  final RemoteCommandService _commandService;
  final DeviceRepository _deviceRepository;
  final AppDiagnosticsRecorder? _diagnosticsRecorder;

  Future<void> cancelPairing({required TvDevice device}) =>
      _commandService.cancelPairing(device: device);

  Future<PairingAttemptResult> pairSelectedDevice({
    required TvDevice device,
    String? manualIpToSave,
    required Future<String?> Function(
      String pairingMessage,
      PinFormat pinFormat,
    )
    promptPin,
    required void Function(String retryMessage) onPinRejected,
  }) async {
    final pairingResult = await _commandService.preparePairing(device: device);
    if (pairingResult.isPinRequired) {
      final pairingMessage = pairingResult.message;
      final paired = await _attemptPinPairing(
        device: device,
        pairingMessage: pairingMessage,
        pinFormat: pairingResult.pinFormat,
        promptPin: promptPin,
        onPinRejected: onPinRejected,
      );
      if (!paired) {
        _diagnosticsRecorder?.recordPairingSession(
          brand: device.brand,
          success: false,
        );
        return PairingAttemptResult.failure(pairingMessage);
      }
    } else if (!pairingResult.isSuccess) {
      _diagnosticsRecorder?.recordPairingSession(
        brand: device.brand,
        success: false,
      );
      return PairingAttemptResult.failure(
        MessageHandler.sanitize(pairingResult),
      );
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
    _diagnosticsRecorder?.recordPairingSession(
      brand: device.brand,
      success: true,
    );
    return PairingAttemptResult.success();
  }

  Future<bool> _attemptPinPairing({
    required TvDevice device,
    required String pairingMessage,
    required PinFormat pinFormat,
    required Future<String?> Function(String, PinFormat) promptPin,
    required void Function(String) onPinRejected,
  }) async {
    while (true) {
      final pin = await promptPin(pairingMessage, pinFormat);
      if (pin == null) return false;
      final submitResult = await _commandService.submitPairingCode(
        device: device,
        pinCode: pin,
      );
      if (submitResult.isSuccess) return true;
      onPinRejected(MessageHandler.sanitize(submitResult));
    }
  }
}

enum PairingOutcome { success, failure }

final class PairingAttemptResult extends Result {
  PairingAttemptResult.success()
    : super(outcome: PairingOutcome.success.name, message: '');
  PairingAttemptResult.failure(String message)
    : super(outcome: PairingOutcome.failure.name, message: message);

  PairingOutcome getOutcome() => PairingOutcome.values.byName(outcome);

  @override
  bool get isSuccess => getOutcome() == PairingOutcome.success;
}
