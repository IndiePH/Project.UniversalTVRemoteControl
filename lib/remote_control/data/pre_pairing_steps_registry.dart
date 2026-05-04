import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

abstract interface class PrePairingStepsRegistry {
  List<String>? stepsFor(TvBrand brand, String protocolVariant);
}

class DefaultPrePairingStepsRegistry implements PrePairingStepsRegistry {
  DefaultPrePairingStepsRegistry({required LocalizedStrings localizedStrings})
    : _localizedStrings = localizedStrings;

  final LocalizedStrings _localizedStrings;

  @override
  List<String>? stepsFor(TvBrand brand, String protocolVariant) =>
      switch ((brand, protocolVariant)) {
        (TvBrand.lg, TvDevice.defaultProtocolVariant) => [
          _localizedStrings.pairingLgPreStep0,
          _localizedStrings.pairingLgPreStep1,
        ],
        (TvBrand.samsung, TvDevice.defaultProtocolVariant) => [
          _localizedStrings.pairingSamsungPreStep0,
          _localizedStrings.pairingSamsungPreStep1,
        ],
        (TvBrand.androidTv, TvDevice.defaultProtocolVariant) => [
          _localizedStrings.pairingAndroidTvPreStep0,
          _localizedStrings.pairingAndroidTvPreStep1,
        ],
        _ => null,
      };
}
