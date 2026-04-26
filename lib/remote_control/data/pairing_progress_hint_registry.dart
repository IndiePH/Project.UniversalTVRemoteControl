import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

abstract interface class PairingProgressHintRegistry {
  String? hintFor(TvBrand brand, String protocolVariant);
}

class DefaultPairingProgressHintRegistry implements PairingProgressHintRegistry {
  const DefaultPairingProgressHintRegistry();

  static const Map<(TvBrand, String), String> _hints = {
    (TvBrand.lg, TvDevice.defaultProtocolVariant):
        'Look at your TV screen and accept the pairing prompt.',
    (TvBrand.samsung, TvDevice.defaultProtocolVariant):
        'Accept any connection permission that appears on your TV.',
    (TvBrand.hisense, TvDevice.defaultProtocolVariant):
        'Connecting to TV\u2026',
  };

  @override
  String? hintFor(TvBrand brand, String protocolVariant) =>
      _hints[(brand, protocolVariant)];
}
