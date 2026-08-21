// LEGACY — retained for backward compatibility only.
//
// Resolves a TV host IP by regex-extracting it from the legacy IP-derived
// `TvDevice.id` (e.g. "samsung-192.168.1.10"). This was the pre-stable-id
// transport host resolution strategy. New code resolves the host via the
// [DeviceIdentityRegistry] reverse lookup (stable id -> host) instead.
// This helper remains only until the transport resolver is switched over
// (Phase 4 step 6) and for the lazy per-device migration that reads old
// IP-derived ids.

/// Extracts an IPv4 host from a legacy IP-derived device id string.
///
/// @deprecated New code must obtain the host from [DeviceIdentityRegistry]
/// rather than parsing it out of the device id.
class LegacyHostResolver {
  static final RegExp _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');

  /// Returns the IPv4 embedded in [deviceId], or an empty string if none.
  static String hostFromDeviceId(String deviceId) {
    final match = _ipv4.firstMatch(deviceId);
    return match?.group(1) ?? '';
  }
}
