import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/device_support_tier.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Maps discovered devices to support tier and pairing-list ordering.
final class DiscoveredDeviceSupport {
  const DiscoveredDeviceSupport._();

  static DeviceSupportTier tierFor(TvDevice device) {
    return switch ((device.brand, device.protocolVariant)) {
      (TvBrand.samsung, _) || (TvBrand.lg, _) => DeviceSupportTier.full,
      (TvBrand.hisense, _) => DeviceSupportTier.limited,
      (TvBrand.roku, _) => DeviceSupportTier.limited,
      (TvBrand.tcl, TclProtocolVariants.legacyWifi) => DeviceSupportTier.limited,
      (TvBrand.androidTv, _) => DeviceSupportTier.experimental,
      (TvBrand.tcl, _) => DeviceSupportTier.experimental,
    };
  }

  /// Lower sorts earlier (full support TVs first).
  static int compareForDiscoveryList(TvDevice a, TvDevice b) {
    final tierOrder = tierFor(a).index.compareTo(tierFor(b).index);
    if (tierOrder != 0) return tierOrder;
    return a.displayName.compareTo(b.displayName);
  }

  /// Relative confidence when multiple discovery paths report the same IP.
  static int brandIdentificationPriority(TvBrand brand) => switch (brand) {
    TvBrand.samsung => 0,
    TvBrand.lg => 1,
    TvBrand.hisense => 2,
    TvBrand.roku => 3,
    TvBrand.androidTv => 4,
    TvBrand.tcl => 5,
  };

}
