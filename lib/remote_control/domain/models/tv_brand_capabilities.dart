import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';

/// Canonical default capability sets by TV brand.
///
/// Use when constructing discovered/manual devices before protocol-level
/// feature probing is available.
extension TvBrandCapabilities on TvBrand {
  static const bool _samsungTextInputEnabled = bool.fromEnvironment(
    'SAMSUNG_ENABLE_TEXT_INPUT',
    defaultValue: false,
  );
  Set<DeviceCapability> get defaultCapabilities {
    return switch (this) {
      TvBrand.samsung => const {
        DeviceCapability.keyCommands,
        if (_samsungTextInputEnabled) DeviceCapability.textInput,
        DeviceCapability.powerControl,
      },
      TvBrand.lg => const {
        DeviceCapability.keyCommands,
        DeviceCapability.textInput,
        DeviceCapability.powerControl,
      },
      TvBrand.hisense => const {
        DeviceCapability.keyCommands,
        DeviceCapability.powerControl,
        DeviceCapability.pinPairing,
      },
    };
  }
}
