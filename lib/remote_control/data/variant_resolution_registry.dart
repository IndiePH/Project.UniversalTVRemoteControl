import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

abstract interface class VariantResolutionRegistry {
  String? resolve({required TvBrand brand, required TvDeviceInfo? info});
}

class _VariantResolutionEntry {
  const _VariantResolutionEntry({required this.matches, required this.variant});

  final bool Function(TvDeviceInfo info) matches;
  final String variant;
}

class DefaultVariantResolutionRegistry implements VariantResolutionRegistry {
  const DefaultVariantResolutionRegistry();

  // Only brands with a genuine info-based dialect rule need an entry. No
  // entry ("no opinion") is correct for every other brand — the caller falls
  // back to device.protocolVariant, which is already correct (constructor
  // default, or whatever discovery-time resolution already stamped).
  static final Map<TvBrand, List<_VariantResolutionEntry>> _entriesByBrand = {
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
  String? resolve({required TvBrand brand, required TvDeviceInfo? info}) {
    if (info == null) return null;

    final entries = _entriesByBrand[brand];
    if (entries == null) return null;

    for (final entry in entries) {
      if (entry.matches(info)) return entry.variant;
    }

    return null;
  }
}
