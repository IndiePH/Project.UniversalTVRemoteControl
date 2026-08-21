import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/data/adapters/tcl/tcl_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';

/// A TV the user can control.
///
/// ## Identity (Phase 4)
/// [id] is the device's **stable identifier** — an IP-independent token
/// derived from the physical TV (e.g. `samsung-<udn>`, `roku-<serial>`,
/// `androidtv-<certSha256>`). It survives LAN IP changes, so a paired TV
/// stays paired after a router reboot re-issues addresses.
///
/// For devices that could not be stably identified at discovery/pairing (e.g.
/// an SSDP response with no UDN, or a manual IP entry whose brand yields no
/// stable id), [id] falls back to an IP-derived value (`<brand>-<ip>`). Such
/// devices report [hasStableId] `false` and are treated as legacy: they are
/// not matched by reconciliation, not registered in the identity registry,
/// and their host is resolved by the legacy regex resolver.
///
/// [host] is the current LAN IPv4 used by transports; it is mutable metadata
/// refreshed by reconciliation when the TV moves to a new IP. It is nullable
/// for legacy/test devices; [resolvedHost] backfills it from [id] in that
/// case. [displayName] (which may include the IP) is what users see — [id] is
/// internal.
class TvDevice {
  const TvDevice({
    required this.id,
    required this.displayName,
    required this.brand,
    required this.capabilities,
    this.protocolVariant = defaultProtocolVariant,
    this.modelIdentifier,
    this.host,
  });

  static const String defaultProtocolVariant = 'default';

  /// IPv4 extractor used to detect legacy IP-derived [id] values and to
  /// backfill [host] from [id] when loading persisted blobs written before
  /// [host] was stored.
  static final RegExp _ipv4 = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})');

  final String id;
  final String displayName;
  final TvBrand brand;
  final Set<DeviceCapability> capabilities;
  final String protocolVariant;
  final String? modelIdentifier;

  /// Current LAN host (IPv4) used by transports. Null for devices constructed
  /// before the stable-id migration; [resolvedHost] backfills it from [id] in
  /// that case.
  final String? host;

  /// Whether [id] is a real stable identifier (true) or an IP-derived fallback
  /// (false). Stable ids never embed a raw IPv4; IP-derived ids do.
  bool get hasStableId => !_ipv4.hasMatch(id);

  /// The host transports should connect to. Prefers the explicit [host];
  /// falls back to an IPv4 parsed from [id] for legacy/migration entries.
  String get resolvedHost {
    final h = host;
    if (h != null && h.isNotEmpty) return h;
    return _ipv4.firstMatch(id)?.group(1) ?? '';
  }

  TvDevice copyWith({
    String? id,
    String? displayName,
    Set<DeviceCapability>? capabilities,
    String? protocolVariant,
    String? modelIdentifier,
    String? host,
  }) => TvDevice(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    brand: brand,
    capabilities: capabilities ?? this.capabilities,
    protocolVariant: protocolVariant ?? this.protocolVariant,
    modelIdentifier: modelIdentifier ?? this.modelIdentifier,
    host: host ?? this.host,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'brand': brand.name,
    'capabilities': capabilities.map((c) => c.name).toList(),
    'protocolVariant': protocolVariant,
    'modelIdentifier': modelIdentifier,
    'host': host,
  };

  static TvDevice? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String;
      final displayName = json['displayName'] as String;
      final brand = TvBrand.values.firstWhere((b) => b.name == json['brand']);
      final protocolVariant =
          json['protocolVariant'] as String? ?? defaultProtocolVariant;
      final (effectiveBrand, effectiveVariant) = switch ((
        brand,
        protocolVariant,
      )) {
        (TvBrand.tcl, TclProtocolVariants.roku) => (
          TvBrand.roku,
          defaultProtocolVariant,
        ),
        (TvBrand.tcl, TclProtocolVariants.googleTv) => (
          TvBrand.androidTv,
          defaultProtocolVariant,
        ),
        _ => (brand, protocolVariant),
      };
      final modelIdentifier = json['modelIdentifier'] as String?;
      // Backfill host from the legacy IP-derived id when absent, so persisted
      // blobs written before host was stored load with a usable host.
      final hostRaw = (json['host'] as String?)?.trim();
      final effectiveHost =
          (hostRaw != null && hostRaw.isNotEmpty)
              ? hostRaw
              : _ipv4.firstMatch(id)?.group(1);
      final capabilityNames =
          (json['capabilities'] as List<dynamic>?)?.cast<String>() ?? [];
      final parsed = capabilityNames
          .map((n) {
            try {
              return DeviceCapability.values.byName(n);
            } catch (_) {
              return null;
            }
          })
          .nonNulls
          .toSet();
      final capabilities = parsed.isEmpty
          ? const TvCapabilities().capabilitiesFor(
              effectiveBrand,
              effectiveVariant,
            )
          : parsed;
      return TvDevice(
        id: id,
        displayName: displayName,
        brand: effectiveBrand,
        capabilities: capabilities,
        protocolVariant: effectiveVariant,
        modelIdentifier: modelIdentifier,
        host: effectiveHost,
      );
    } catch (_) {
      return null;
    }
  }
}
