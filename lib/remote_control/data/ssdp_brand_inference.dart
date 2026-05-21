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
  if (probe.contains('androidtvremote') ||
      probe.contains('_androidtvremote')) {
    return TvBrand.androidTv;
  }
  return null;
}
