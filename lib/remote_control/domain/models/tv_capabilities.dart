import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/pin_format.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_protocol_variants.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Canonical capability sets indexed by (brand, protocolVariant).
///
/// [capabilitiesFor] is the single call site for all capability lookups —
/// pre-pairing (brand-only, no variant) and post-pairing (brand + resolved
/// variant). Unknown variants fall back to the brand's default-variant entry.
class TvCapabilities {
  const TvCapabilities();

  static const bool _hisenseTextInputEnabled = bool.fromEnvironment(
    'HISENSE_ENABLE_TEXT_INPUT',
    defaultValue: false,
  );

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
      DeviceCapability.textInput,
    },
    (TvBrand.roku, TvDevice.defaultProtocolVariant): {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
    },
    (TvBrand.sony, TvDevice.defaultProtocolVariant): {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
      DeviceCapability.pinPairing,
      DeviceCapability.textInput,
    },
    (TvBrand.sony, SonyProtocolVariants.braviaIpControl): {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
      DeviceCapability.pinPairing,
    },
    (TvBrand.tcl, TclProtocolVariants.legacyWifi): {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
    },
    (TvBrand.tcl, TvDevice.defaultProtocolVariant): {
      DeviceCapability.keyCommands,
      DeviceCapability.powerControl,
    },
  };

  Set<DeviceCapability> capabilitiesFor(TvBrand brand, [String? variant]) {
    final v = variant ?? TvDevice.defaultProtocolVariant;
    final base =
        _map[(brand, v)] ??
        _map[(brand, TvDevice.defaultProtocolVariant)] ??
        {};
    if (brand == TvBrand.hisense && _hisenseTextInputEnabled) {
      return <DeviceCapability>{...base, DeviceCapability.textInput};
    }
    return base;
  }

  PinFormat pinFormatFor(TvBrand brand, [String? variant]) =>
      switch ((brand, variant)) {
        (TvBrand.sony, SonyProtocolVariants.braviaIpControl) =>
          PinFormat.freeform,
        (TvBrand.androidTv, _) => PinFormat.sixCharHex,
        (TvBrand.sony, _) => PinFormat.sixCharHex,
        (TvBrand.hisense, _) => PinFormat.fourDigitNumeric,
        _ => throw StateError(
          'PIN format not configured for ${brand.name} — '
          'add an entry in TvCapabilities.pinFormatFor',
        ),
      };
}
