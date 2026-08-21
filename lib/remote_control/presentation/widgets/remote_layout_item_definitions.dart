import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/domain/models/layout_zone.dart';
import 'package:one_remote/remote_control/domain/models/layout_item_id.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/streaming_service_brand_assets.dart';

/// Default metadata for each control id (ids, labels, icons, default grid footprint).
///
/// **Layout geometry** for the running app is whatever [LayoutEditItem] holds on [RemoteHomePage]
/// (`col`, `row`, `width`, `height`) — one shared list for main and edit. This file seeds those
/// defaults and supplies stable ids.
///
/// **Look and feel** in edit mode is allowed to differ from the main remote: [RemoteLayoutPreviewStyle]
/// and editor-only styling are hints for drag-and-drop previews, not a promise of pixel parity with
/// the live control (labels, color, or widget choice may diverge when useful).
enum RemoteLayoutPreviewStyle {
  standard,
  playPause,
  centeredCircleIcon,
  circularDpad,
  verticalRocker,
}

class RemoteLayoutItemDefinition {
  const RemoteLayoutItemDefinition({
    required this.id,
    this.icon,
    this.imageAsset,
    this.imageIconSize,
    this.brandColor,
    this.label,
    required this.col,
    required this.row,
    this.width = 1,
    this.height = 1,
    this.isPower = false,
    this.previewStyle = RemoteLayoutPreviewStyle.standard,
    this.commands = const <RemoteCommand>{},
  });

  final String id;
  final IconData? icon;
  final String? imageAsset;
  final double? imageIconSize;
  final Color? brandColor;
  final String? label;
  final int col;
  final int row;
  final int width;
  final int height;
  final bool isPower;
  final RemoteLayoutPreviewStyle previewStyle;

  /// The commands the device must support for this item to appear at all.
  ///
  /// Example: `volume` needs both `volumeUp` and `volumeDown`, so a device missing either one
  /// won't show the volume button. Empty means "not gated by a command" — today that's only
  /// `searchInput`, which shows or hides based on `supportsTextInput` instead.
  final Set<RemoteCommand> commands;

  /// The command sent when this item is tapped, or `null` if tapping it doesn't map to one
  /// command.
  ///
  /// Set automatically from [commands] when there's exactly one: e.g. `power` has
  /// `commands = {power}`, so this is `power`. It's `null` for `dpad`/`volume`/`channel`
  /// because those have more than one command and no single "the tap action" — pressing
  /// up/down/left/etc. is handled separately, by which part of the control was touched. It's
  /// also `null` for `searchInput`, which has zero commands: tapping it opens a text-input
  /// keyboard instead of sending anything to the TV.
  RemoteCommand? get dispatchCommand =>
      commands.length == 1 ? commands.single : null;

  LayoutEditItem toLayoutEditItem({LayoutZone zone = LayoutZone.grid}) {
    return LayoutEditItem(
      id: id,
      icon: icon,
      imageAsset: imageAsset,
      label: label,
      col: col,
      row: row,
      width: width,
      height: height,
      isPower: isPower,
      zone: zone,
    );
  }
}

const List<RemoteLayoutItemDefinition> kRemoteLayoutItemDefinitions = [
  RemoteLayoutItemDefinition(
    id: LayoutItemId.power,
    icon: Icons.power_settings_new,
    col: 0,
    row: 0,
    isPower: true,
    commands: {RemoteCommand.power},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.menu,
    label: 'MENU',
    col: 4,
    row: 0,
    commands: {RemoteCommand.menu},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.volume,
    label: 'VOL',
    col: 0,
    row: 2,
    height: 3,
    previewStyle: RemoteLayoutPreviewStyle.verticalRocker,
    commands: {RemoteCommand.volumeUp, RemoteCommand.volumeDown},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.playPause,
    label: '|>||',
    col: 1,
    row: 1,
    previewStyle: RemoteLayoutPreviewStyle.playPause,
    commands: {RemoteCommand.playPause},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.www,
    label: 'WWW',
    col: 3,
    row: 1,
    commands: {RemoteCommand.web},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.dpad,
    label: 'DPAD',
    col: 1,
    row: 2,
    width: 3,
    height: 3,
    previewStyle: RemoteLayoutPreviewStyle.circularDpad,
    commands: {
      RemoteCommand.dpadUp,
      RemoteCommand.dpadDown,
      RemoteCommand.dpadLeft,
      RemoteCommand.dpadRight,
      RemoteCommand.dpadOk,
    },
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.channel,
    label: 'CH',
    col: 4,
    row: 2,
    height: 3,
    previewStyle: RemoteLayoutPreviewStyle.verticalRocker,
    commands: {RemoteCommand.channelUp, RemoteCommand.channelDown},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.home,
    icon: Icons.home_outlined,
    col: 2,
    row: 0,
    commands: {RemoteCommand.home},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.back,
    icon: Icons.arrow_back,
    col: 0,
    row: 5,
    commands: {RemoteCommand.back},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.mute,
    icon: Icons.volume_off,
    col: 4,
    row: 5,
    commands: {RemoteCommand.mute},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.netflix,
    imageAsset: StreamingServiceBrandAssets.netflix,
    brandColor: StreamingServiceBrandAssets.netflixBrand,
    col: 1,
    row: 5,
    commands: {RemoteCommand.netflix},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.disney,
    imageAsset: StreamingServiceBrandAssets.disneyPlus,
    col: 2,
    row: 5,
    commands: {RemoteCommand.disneyPlus},
  ),
  RemoteLayoutItemDefinition(
    id: LayoutItemId.prime,
    imageAsset: StreamingServiceBrandAssets.primeVideo,
    brandColor: StreamingServiceBrandAssets.primeVideoBrand,
    col: 3,
    row: 5,
    commands: {RemoteCommand.primeVideo},
  ),

  /// Single cell; same footprint on main remote and layout editor.
  RemoteLayoutItemDefinition(
    id: LayoutItemId.searchInput,
    icon: Icons.keyboard_outlined,
    col: 2,
    row: 6,
    previewStyle: RemoteLayoutPreviewStyle.centeredCircleIcon,
  ),

  /// Placeholder default position — cosmetic only. Stacked under netflix, per user direction.
  RemoteLayoutItemDefinition(
    id: LayoutItemId.youtube,
    icon: Icons.smart_display_outlined,
    col: 1,
    row: 6,
    commands: {RemoteCommand.youtube},
  ),

  /// Placeholder default position — cosmetic only. Stacked under youtube, per user direction.
  RemoteLayoutItemDefinition(
    id: LayoutItemId.input,
    icon: Icons.input,
    col: 1,
    row: 7,
    commands: {RemoteCommand.input},
  ),
];

final Map<String, RemoteLayoutItemDefinition> kRemoteLayoutItemDefinitionById =
    {
      for (final definition in kRemoteLayoutItemDefinitions)
        definition.id: definition,
    };

List<LayoutEditItem> buildInitialRemoteLayoutItems() {
  return kRemoteLayoutItemDefinitions
      .map((definition) => definition.toLayoutEditItem())
      .toList(growable: true);
}

Set<RemoteCommand> requiredCommandsForLayoutItemId(String itemId) {
  return kRemoteLayoutItemDefinitionById[itemId]?.commands ??
      const <RemoteCommand>{};
}

RemoteCommand? commandForLayoutItemId(String itemId) {
  return kRemoteLayoutItemDefinitionById[itemId]?.dispatchCommand;
}

/// Whether [itemId] starts on the grid or parked in the drawer.
///
/// `defaultPositionedIds` is the set of ids considered "on by default" for the current
/// device — today that's `null` everywhere (no narrower-than-full-catalog default set
/// exists yet; see `goal-variant-remote-layout.md`), which this treats as "everything is
/// default" so every eligible item still starts on the grid. Once a real default set exists,
/// passing it here is the only change needed — this function doesn't need to change shape.
LayoutZone resolveDefaultLayoutItemZone({
  required String itemId,
  required Set<String>? defaultPositionedIds,
}) {
  if (defaultPositionedIds == null) {
    return LayoutZone.grid;
  }
  return defaultPositionedIds.contains(itemId)
      ? LayoutZone.grid
      : LayoutZone.drawer;
}

List<LayoutEditItem> buildFilteredRemoteLayoutItems({
  required Set<RemoteCommand> supportedCommands,
  required bool supportsTextInput,
  Set<String> forceIncludeIds = const <String>{},
  Set<String>? defaultPositionedIds,
}) {
  final items = <LayoutEditItem>[];
  for (final definition in kRemoteLayoutItemDefinitions) {
    final id = definition.id;
    final zone = resolveDefaultLayoutItemZone(
      itemId: id,
      defaultPositionedIds: defaultPositionedIds,
    );
    if (id == LayoutItemId.searchInput) {
      if (!supportsTextInput && !forceIncludeIds.contains(id)) {
        continue;
      }
      items.add(definition.toLayoutEditItem(zone: zone));
      continue;
    }
    final commands = definition.commands;
    if (commands.isEmpty || forceIncludeIds.contains(id)) {
      items.add(definition.toLayoutEditItem(zone: zone));
      continue;
    }
    if (supportedCommands.containsAll(commands)) {
      items.add(definition.toLayoutEditItem(zone: zone));
    }
  }
  return items;
}
