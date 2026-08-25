import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract interface class VariantResolutionRegistry {
  String resolve({required TvBrand brand, required TvDeviceInfo? info});
}

class _VariantResolutionEntry {
  const _VariantResolutionEntry({required this.matches, required this.variant});

  final bool Function(TvDeviceInfo info) matches;
  final String variant;
}

class DefaultVariantResolutionRegistry implements VariantResolutionRegistry {
  const DefaultVariantResolutionRegistry();

  static final Map<TvBrand, List<_VariantResolutionEntry>> _entriesByBrand = {
    TvBrand.lg: [
      _VariantResolutionEntry(
        matches: (_) => true,
        variant: TvDevice.defaultProtocolVariant,
      ),
    ],
    TvBrand.samsung: [
      _VariantResolutionEntry(
        matches: (_) => true,
        variant: TvDevice.defaultProtocolVariant,
      ),
    ],
    TvBrand.hisense: [
      _VariantResolutionEntry(
        matches: (_) => true,
        variant: TvDevice.defaultProtocolVariant,
      ),
    ],
    TvBrand.androidTv: [
      _VariantResolutionEntry(
        matches: (_) => true,
        variant: TvDevice.defaultProtocolVariant,
      ),
    ],
    TvBrand.roku: [
      _VariantResolutionEntry(
        matches: (_) => true,
        variant: TvDevice.defaultProtocolVariant,
      ),
    ],
    TvBrand.sony: [
      _VariantResolutionEntry(
        matches: (_) => true,
        variant: TvDevice.defaultProtocolVariant,
      ),
    ],
    // ── TCL (legacy Wi-Fi only; no default-variant adapter registered) ───────
    TvBrand.tcl: [
      _VariantResolutionEntry(
        matches: TclProtocolVariants.isLegacyWifi,
        variant: TclProtocolVariants.legacyWifi,
      ),
      _VariantResolutionEntry(
        matches: (_) => true,
        variant: TclProtocolVariants.legacyWifi,
      ),
    ],
  };

  @override
  String resolve({required TvBrand brand, required TvDeviceInfo? info}) {
    if (info == null) return TvDevice.defaultProtocolVariant;

    final entries = _entriesByBrand[brand];

    if (entries == null) return TvDevice.defaultProtocolVariant;

    for (final entry in entries) {
      if (entry.matches(info)) return entry.variant;
    }

    return TvDevice.defaultProtocolVariant;
  }
}
