import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract interface class VariantResolutionRegistry {
  String resolve({required TvBrand brand, required TvDeviceInfo? info});
}

class _VariantResolutionEntry {
  const _VariantResolutionEntry({
    required this.brand,
    required this.matches,
    required this.variant,
  });

  final TvBrand brand;
  final bool Function(TvDeviceInfo info) matches;
  final String variant;
}

class DefaultVariantResolutionRegistry implements VariantResolutionRegistry {
  const DefaultVariantResolutionRegistry();

  static final _entries = <_VariantResolutionEntry>[
    _VariantResolutionEntry(
      brand: TvBrand.lg,
      matches: (_) => true,
      variant: TvDevice.defaultProtocolVariant,
    ),
    _VariantResolutionEntry(
      brand: TvBrand.samsung,
      matches: (_) => true,
      variant: TvDevice.defaultProtocolVariant,
    ),
    _VariantResolutionEntry(
      brand: TvBrand.hisense,
      matches: (_) => true,
      variant: TvDevice.defaultProtocolVariant,
    ),
    _VariantResolutionEntry(
      brand: TvBrand.androidTv,
      matches: (_) => true,
      variant: TvDevice.defaultProtocolVariant,
    ),
    _VariantResolutionEntry(
      brand: TvBrand.roku,
      matches: (_) => true,
      variant: TvDevice.defaultProtocolVariant,
    ),
    // ── TCL (legacy Wi-Fi only; no default-variant adapter registered) ───────
    _VariantResolutionEntry(
      brand: TvBrand.tcl,
      matches: TclProtocolVariants.isLegacyWifi,
      variant: TclProtocolVariants.legacyWifi,
    ),
    _VariantResolutionEntry(
      brand: TvBrand.tcl,
      matches: (_) => true,
      variant: TclProtocolVariants.legacyWifi,
    ),
  ];

  @override
  String resolve({required TvBrand brand, required TvDeviceInfo? info}) {
    if (info == null) return TvDevice.defaultProtocolVariant;
    for (final entry in _entries) {
      if (entry.brand == brand && entry.matches(info)) return entry.variant;
    }
    return TvDevice.defaultProtocolVariant;
  }
}
