import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/sony/sony_protocol_variants.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Resolves which `protocolVariant` to use for a manually-typed brand + IP,
/// by probing each of the brand's known variants and taking whichever one
/// answers — see `guide-protocol-variants.md`'s mechanism #3.
///
/// Neither `DiscoveryVariantResolutionRegistry` (needs a `DiscoverySource`)
/// nor `VariantResolutionRegistry` (needs a live `TvDeviceInfo`) can answer
/// this: manual add has no discovery source and no probe result yet. This is
/// the only one of the three resolvers that does its own network I/O.
abstract interface class ManualAddVariantProbe {
  Future<String> resolve({required TvBrand brand, required String host});
}

class DefaultManualAddVariantProbe implements ManualAddVariantProbe {
  DefaultManualAddVariantProbe({required this._adapters});

  final List<TvBrandAdapter> _adapters;

  /// Try-order between a brand's own variants, for brands with more than one.
  /// Nothing else needs this today — Sony is the only brand with two live
  /// variants under one brand. Google TV path first: it's the existing,
  /// already-validated path.
  static const Map<TvBrand, List<String>> _variantTryOrder = {
    TvBrand.sony: [
      SonyProtocolVariants.defaultVariant,
      SonyProtocolVariants.braviaIpControl,
    ],
  };

  @override
  Future<String> resolve({required TvBrand brand, required String host}) async {
    final candidates = _adapters.where((a) => a.brand == brand).toList();
    // No I/O when there's nothing to disambiguate — every brand except Sony
    // has exactly one adapter today.
    if (candidates.length <= 1) {
      return candidates.isEmpty
          ? TvDevice.defaultProtocolVariant
          : candidates.first.protocolVariant;
    }
    for (final adapter in _orderedByPreference(brand, candidates)) {
      final probeDevice = TvDevice(
        id: 'manual-add-probe',
        displayName: 'Manual add probe',
        brand: brand,
        capabilities: const {},
        protocolVariant: adapter.protocolVariant,
        host: host,
      );
      try {
        await adapter.probeConnection(device: probeDevice);
        return adapter.protocolVariant;
      } catch (_) {
        // Not this variant — try the next candidate.
      }
    }
    return TvDevice.defaultProtocolVariant;
  }

  List<TvBrandAdapter> _orderedByPreference(
    TvBrand brand,
    List<TvBrandAdapter> candidates,
  ) {
    final order = _variantTryOrder[brand];
    if (order == null) {
      return candidates;
    }
    final ordered = <TvBrandAdapter>[
      for (final variant in order)
        ...candidates.where((a) => a.protocolVariant == variant),
    ];
    // A candidate whose variant isn't listed in _variantTryOrder must still
    // be tried (deprioritized, not dropped) — otherwise a third variant ever
    // added to this brand without updating the map above would silently
    // never get probed at all.
    final unlisted = candidates.where((a) => !ordered.contains(a));
    return [...ordered, ...unlisted];
  }
}
