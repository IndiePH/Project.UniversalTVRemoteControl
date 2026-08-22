import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';

/// Per-(brand, protocolVariant) overrides of the default remote layout.
///
/// Mirrors `TvCapabilities`' fallback shape: only brand+variants with a real reason to
/// diverge get an entry here; everything else falls through to
/// [kRemoteLayoutItemDefinitions]. Lives beside [RemoteLayoutItemDefinition] rather than in
/// `domain/models` (where `TvCapabilities` lives) because [RemoteLayoutItemDefinition] itself
/// depends on Flutter types (`IconData`, `Color`) and presentation-only assets — putting this
/// class in `domain/models` would make domain code depend on presentation code.
class RemoteLayoutDefaults {
  const RemoteLayoutDefaults();

  static final Map<(TvBrand, String), List<RemoteLayoutItemDefinition>> _map = {
    // example — hypothetical: Android TV's default variant omits the dedicated
    // channel button entirely (no replacement), e.g. if most Android TV devices
    // in this category have no tuner. Everything else falls through unchanged:
    //
    //  (TvBrand.androidTv, AndroidTvProtocolVariants.defaultVariant): [
    //    for (final definition in kRemoteLayoutItemDefinitions)
    //      if (definition.id != LayoutItemId.channel) definition,
    //  ],
    //
    // Omitting an id like this removes it from the catalog entirely — see
    // "When does an item actually show up?" in guide-adding-variant-remote-layout.md
    // for what that means for a device with a pre-existing saved customization.
  };

  List<RemoteLayoutItemDefinition> layoutFor(TvBrand brand, [String? variant]) {
    final v = variant ?? TvDevice.defaultProtocolVariant;
    return _map[(brand, v)] ??
        _map[(brand, TvDevice.defaultProtocolVariant)] ??
        kRemoteLayoutItemDefinitions;
  }
}

/// Merges [kRemoteLayoutItemDefinitionById] with whatever [RemoteLayoutDefaults] resolves for
/// (brand, protocolVariant), so a caller looking up any item id by name gets the variant's
/// override when one exists and the baseline definition otherwise.
Map<String, RemoteLayoutItemDefinition> resolveItemDefinitionsById({
  required TvBrand brand,
  required String protocolVariant,
}) {
  final overrides = const RemoteLayoutDefaults().layoutFor(
    brand,
    protocolVariant,
  );
  return {
    ...kRemoteLayoutItemDefinitionById,
    for (final definition in overrides) definition.id: definition,
  };
}
