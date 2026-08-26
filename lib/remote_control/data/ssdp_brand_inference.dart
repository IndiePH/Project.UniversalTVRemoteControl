import 'package:one_remote/remote_control/domain/models/tv_brand.dart';

/// SSDP/UPnP header probe used to identify supported TV brands.
String ssdpDiscoveryProbeText(Map<String, String> headers) {
  return [
    headers['server'] ?? '',
    headers['st'] ?? '',
    headers['nt'] ?? '',
    headers['usn'] ?? '',
    headers['location'] ?? '',
  ].join(' ');
}

/// Extracts the UPnP UDN (device UUID) from SSDP headers, when present.
///
/// SSDP `USN` commonly takes forms like `uuid:<uuid>::upnp:rootdevice` or
/// `uuid:<uuid>`. Returns the bare UUID (no `uuid:` prefix) so it can be used
/// directly as a stable per-device identifier. Returns null when no UUID is
/// found — callers must fall back to an IP-derived identity in that case.
String? udnFromSsdpHeaders(Map<String, String> headers) {
  final usn = headers['usn'];
  if (usn == null || usn.isEmpty) return null;
  final match = RegExp(
    r'uuid:([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
  ).firstMatch(usn);
  return match?.group(1);
}

/// Returns a supported [TvBrand] when SSDP headers match a known fingerprint.
TvBrand? inferSsdpTvBrand(Map<String, String> headers) {
  final probe = ssdpDiscoveryProbeText(headers).toLowerCase();
  if (probe.contains('roku')) {
    return TvBrand.roku;
  }
  if (probe.contains('samsung') || probe.contains('tizen')) {
    return TvBrand.samsung;
  }
  if (probe.contains('lg') || probe.contains('webos')) {
    return TvBrand.lg;
  }
  if (probe.contains('hisense') ||
      probe.contains('vidaa') ||
      probe.contains('hiview')) {
    return TvBrand.hisense;
  }
  if (probe.contains('androidtvremote') || probe.contains('_androidtvremote')) {
    return TvBrand.androidTv;
  }
  // `scalarwebapi` (urn:schemas-sony-com:service:ScalarWebAPI:1), not bare
  // `sony` — that URN is also used by Sony's non-TV "Songpal" audio gear, but
  // a bare `sony` match would additionally catch cameras and other Sony
  // devices with no relation to ScalarWebAPI at all.
  if (probe.contains('scalarwebapi')) {
    return TvBrand.sony;
  }
  return null;
}
