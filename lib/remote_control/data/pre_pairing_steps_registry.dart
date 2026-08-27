import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

abstract interface class PrePairingStepsRegistry {
  List<String>? stepsFor(TvBrand brand, String protocolVariant);
}

class DefaultPrePairingStepsRegistry implements PrePairingStepsRegistry {
  DefaultPrePairingStepsRegistry({required this._localizedStrings});

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
        (TvBrand.sony, TvDevice.defaultProtocolVariant) => [
          _localizedStrings.pairingSonyPreStep0,
          _localizedStrings.pairingSonyPreStep1,
        ],
        (TvBrand.roku, TvDevice.defaultProtocolVariant) => [
          _localizedStrings.pairingRokuPreStep0,
          _localizedStrings.pairingRokuPreStep1,
        ],
        (TvBrand.tcl, TclProtocolVariants.legacyWifi) => [
          _localizedStrings.pairingTclLegacyPreStep0,
          _localizedStrings.pairingTclLegacyPreStep1,
        ],
        _ => null,
      };
}
