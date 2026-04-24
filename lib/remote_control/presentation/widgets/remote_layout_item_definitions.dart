import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';

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
    this.label,
    required this.col,
    required this.row,
    this.width = 1,
    this.height = 1,
    this.isPower = false,
    this.previewStyle = RemoteLayoutPreviewStyle.standard,
  });

  final String id;
  final IconData? icon;
  final String? label;
  final int col;
  final int row;
  final int width;
  final int height;
  final bool isPower;
  final RemoteLayoutPreviewStyle previewStyle;

  LayoutEditItem toLayoutEditItem() {
    return LayoutEditItem(
      id: id,
      icon: icon,
      label: label,
      col: col,
      row: row,
      width: width,
      height: height,
      isPower: isPower,
    );
  }
}

const List<RemoteLayoutItemDefinition> kRemoteLayoutItemDefinitions = [
  RemoteLayoutItemDefinition(
    id: 'power',
    icon: Icons.power_settings_new,
    col: 0,
    row: 0,
    isPower: true,
  ),
  RemoteLayoutItemDefinition(id: 'pair', icon: Icons.wifi, col: 4, row: 0),
  RemoteLayoutItemDefinition(id: 'menu', label: 'MENU', col: 2, row: 0),
  RemoteLayoutItemDefinition(
    id: 'volume',
    label: 'VOL',
    col: 0,
    row: 3,
    height: 3,
    previewStyle: RemoteLayoutPreviewStyle.verticalRocker,
  ),
  RemoteLayoutItemDefinition(
    id: 'playPause',
    label: '|>||',
    col: 1,
    row: 2,
    previewStyle: RemoteLayoutPreviewStyle.playPause,
  ),
  RemoteLayoutItemDefinition(id: 'www', label: 'WWW', col: 3, row: 2),
  RemoteLayoutItemDefinition(
    id: 'dpad',
    label: 'DPAD',
    col: 1,
    row: 3,
    width: 3,
    height: 3,
    previewStyle: RemoteLayoutPreviewStyle.circularDpad,
  ),
  RemoteLayoutItemDefinition(
    id: 'channel',
    label: 'CH',
    col: 4,
    row: 3,
    height: 3,
    previewStyle: RemoteLayoutPreviewStyle.verticalRocker,
  ),
  RemoteLayoutItemDefinition(id: 'home', icon: Icons.home_outlined, col: 2, row: 1),
  RemoteLayoutItemDefinition(id: 'back', icon: Icons.arrow_back, col: 0, row: 6),
  RemoteLayoutItemDefinition(id: 'mute', icon: Icons.volume_off, col: 4, row: 6),
  RemoteLayoutItemDefinition(id: 'netflix', icon: Icons.movie_filter, col: 1, row: 7),
  RemoteLayoutItemDefinition(id: 'disney', icon: Icons.live_tv, col: 2, row: 7),
  RemoteLayoutItemDefinition(
    id: 'prime',
    icon: Icons.video_library_outlined,
    col: 3,
    row: 7,
  ),
  /// Single cell; same footprint on main remote and layout editor.
  RemoteLayoutItemDefinition(
    id: 'searchInput',
    icon: Icons.keyboard_outlined,
    col: 2,
    row: 8,
    previewStyle: RemoteLayoutPreviewStyle.centeredCircleIcon,
  ),
];

final Map<String, RemoteLayoutItemDefinition> kRemoteLayoutItemDefinitionById = {
  for (final definition in kRemoteLayoutItemDefinitions) definition.id: definition,
};

List<LayoutEditItem> buildInitialRemoteLayoutItems() {
  return kRemoteLayoutItemDefinitions
      .map((definition) => definition.toLayoutEditItem())
      .toList(growable: true);
}
