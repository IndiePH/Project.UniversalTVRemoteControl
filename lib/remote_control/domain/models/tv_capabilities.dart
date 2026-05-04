import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Canonical capability sets indexed by (brand, protocolVariant).
///
/// [capabilitiesFor] is the single call site for all capability lookups —
/// pre-pairing (brand-only, no variant) and post-pairing (brand + resolved
/// variant). Unknown variants fall back to the brand's default-variant entry.
class TvCapabilities {
  const TvCapabilities();

  static const Map<(TvBrand, String), Set<DeviceCapability>> _map = {
    (TvBrand.samsung, TvDevice.defaultProtocolVariant): {
      DeviceCapability.keyCommands,
      DeviceCapability.textInput,
      DeviceCapability.powerControl,
    },
    (TvBrand.lg, TvDevice.defaultProtocolVariant): {
      DeviceCapability.keyCommands,
      DeviceCapability.textInput,
      DeviceCapability.powerControl,
    },
    (TvBrand.hisense, TvDevice.defaultProtocolVariant): {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
      DeviceCapability.pinPairing,
    },
    (TvBrand.androidTv, TvDevice.defaultProtocolVariant): {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
      DeviceCapability.pinPairing,
    },
  };

  Set<DeviceCapability> capabilitiesFor(TvBrand brand, [String? variant]) {
    final v = variant ?? TvDevice.defaultProtocolVariant;
    return _map[(brand, v)] ??
        _map[(brand, TvDevice.defaultProtocolVariant)] ??
        {};
  }
}
