/// Which discovery transport found a TV device, before any adapter has been
/// selected. Used only to resolve a structural protocol variant at
/// construction time — never persisted, never a substitute for
/// TvDeviceInfo-based behavioral resolution.
enum DiscoverySource { ssdp, mdns, roku }
