class TvDeviceInfo {
  const TvDeviceInfo({
    this.modelIdentifier,
    this.firmwareVersion,
    this.debugDetails,
  });

  final String? modelIdentifier;
  final String? firmwareVersion;

  /// Extra transport fields for debug UI (e.g. Samsung OS / frame version).
  final String? debugDetails;
}
