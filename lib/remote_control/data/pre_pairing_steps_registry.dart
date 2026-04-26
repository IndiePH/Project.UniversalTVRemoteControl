import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

abstract interface class PrePairingStepsRegistry {
  List<String>? stepsFor(TvBrand brand, String protocolVariant);
}

class DefaultPrePairingStepsRegistry implements PrePairingStepsRegistry {
  const DefaultPrePairingStepsRegistry();

  static const Map<(TvBrand, String), List<String>> _steps = {
    (TvBrand.lg, TvDevice.defaultProtocolVariant): [
      'Your LG TV is ON and connected to the same Wi-Fi.',
      "When the pairing request appears on your TV screen, tap 'Allow'.",
    ],
    (TvBrand.samsung, TvDevice.defaultProtocolVariant): [
      'Your Samsung TV is ON and connected to the same Wi-Fi.',
      'Accept any connection permission that appears on your TV.',
    ],
  };

  @override
  List<String>? stepsFor(TvBrand brand, String protocolVariant) =>
      _steps[(brand, protocolVariant)];
}
