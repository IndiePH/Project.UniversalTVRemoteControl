class TvDeviceInfo {
  const TvDeviceInfo({
    this.modelIdentifier,
    this.firmwareVersion,
    this.debugDetails,
    this.stableId,
  });

  final String? modelIdentifier;
  final String? firmwareVersion;

  /// Extra transport fields for debug UI (e.g. Samsung OS / frame version).
  final String? debugDetails;

  /// Stable, IP-independent identifier for the physical TV (e.g. Roku serial,
  /// UPnP UDN, Android TV server-cert SHA-256). Populated by adapters during
  /// pairing enrichment and used as the persistent [TvDevice.id].
  final String? stableId;
}
