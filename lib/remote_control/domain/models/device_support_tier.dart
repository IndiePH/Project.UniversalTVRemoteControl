/// How fully a discovered TV brand/protocol is supported in the MVP.
enum DeviceSupportTier {
  /// Samsung / LG — primary validated remote paths.
  full,

  /// Works for core keys but some features are missing or model-dependent.
  limited,

  /// Adapter exists; pairing/commands may be unstable across OEMs.
  experimental,
}
