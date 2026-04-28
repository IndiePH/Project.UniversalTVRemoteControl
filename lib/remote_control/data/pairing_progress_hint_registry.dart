import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

abstract interface class PairingProgressHintRegistry {
  String? hintFor(TvBrand brand, String protocolVariant);
}

class DefaultPairingProgressHintRegistry implements PairingProgressHintRegistry {
  DefaultPairingProgressHintRegistry({required LocalizedStrings localizedStrings})
    : _localizedStrings = localizedStrings;

  final LocalizedStrings _localizedStrings;

  @override
  String? hintFor(TvBrand brand, String protocolVariant) =>
      switch ((brand, protocolVariant)) {
        (TvBrand.lg, TvDevice.defaultProtocolVariant) => _localizedStrings.pairingLgProgressHint,
        (TvBrand.samsung, TvDevice.defaultProtocolVariant) => _localizedStrings.pairingSamsungProgressHint,
        (TvBrand.hisense, TvDevice.defaultProtocolVariant) => _localizedStrings.pairingHisenseProgressHint,
        _ => null,
      };
}
