import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_drop_resolver.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor_grid_geometry.dart';

/// Grab-point within a multi-cell control’s validation footprint (for swap math).
class RemoteLayoutEditorDragAnchor {
  const RemoteLayoutEditorDragAnchor({
    required this.colOffset,
    required this.rowOffset,
  });

  final int colOffset;
  final int rowOffset;
}

/// Resolved snap rectangle and drop validity for hover painting.
class RemoteLayoutEditorActiveDragHover {
  const RemoteLayoutEditorActiveDragHover({
    required this.movingId,
    required this.hoverCol,
    required this.hoverRow,
    required this.snapCol,
    required this.snapRow,
    required this.width,
    required this.height,
    required this.canDrop,
  });

  final String movingId;
  final int hoverCol;
  final int hoverRow;
  final int snapCol;
  final int snapRow;
  final int width;
  final int height;
  final bool canDrop;

  @override
  bool operator ==(Object other) {
    return other is RemoteLayoutEditorActiveDragHover &&
        other.movingId == movingId &&
        other.hoverCol == hoverCol &&
        other.hoverRow == hoverRow &&
        other.snapCol == snapCol &&
        other.snapRow == snapRow &&
        other.width == width &&
        other.height == height &&
        other.canDrop == canDrop;
  }

  @override
  int get hashCode => Object.hash(
    movingId,
    hoverCol,
    hoverRow,
    snapCol,
    snapRow,
    width,
    height,
    canDrop,
  );
}

/// Drag anchor, hover highlight, and [RemoteLayoutDropResolver] wiring for the editor grid.
///
/// Does not call [State.setState]; callers rebuild when mutators return `true`.
class RemoteLayoutEditorDragSession {
  RemoteLayoutEditorDragSession()
    : _dropResolver = RemoteLayoutDropResolver(
        RemoteLayoutEditorGridGeometry.validationFootprintFor,
      );

  final RemoteLayoutDropResolver _dropResolver;
  final Map<String, RemoteLayoutEditorDragAnchor> _dragAnchorOffsetsByItemId =
      <String, RemoteLayoutEditorDragAnchor>{};

  bool isDraggingLayoutItem = false;
  RemoteLayoutEditorActiveDragHover? activeDragHover;
  bool dragAcceptedInCurrentSession = false;

  void recordDragAnchor({
    required LayoutEditItem item,
    required Offset localPosition,
    required double cellSize,
    required double gridGap,
  }) {
    final footprint = RemoteLayoutEditorGridGeometry.validationFootprintFor(
      item,
    );
    final stride = cellSize + gridGap;
    final colOffset = (localPosition.dx / stride).floor().clamp(
      0,
      footprint.width - 1,
    );
    final rowOffset = (localPosition.dy / stride).floor().clamp(
      0,
      footprint.height - 1,
    );
    _dragAnchorOffsetsByItemId[item.id] = RemoteLayoutEditorDragAnchor(
      colOffset: colOffset,
      rowOffset: rowOffset,
    );
  }

  RemoteLayoutEditorDragAnchor dragAnchorForItem(String itemId) {
    return _dragAnchorOffsetsByItemId[itemId] ??
        const RemoteLayoutEditorDragAnchor(colOffset: 0, rowOffset: 0);
  }

  RemoteLayoutResolvedDrop? resolveDrop({
    required int gridColumns,
    required int gridRows,
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required Map<String, String> occupancyByCell,
    required Map<String, LayoutEditItem> itemsById,
  }) {
    final anchor = dragAnchorForItem(movingId);
    return _dropResolver.resolveDrop(
      gridColumns: gridColumns,
      gridRows: gridRows,
      movingId: movingId,
      hoverCol: hoverCol,
      hoverRow: hoverRow,
      occupancyByCell: occupancyByCell,
      itemsById: itemsById,
      anchorColOffset: anchor.colOffset,
      anchorRowOffset: anchor.rowOffset,
    );
  }

  bool willAcceptDropAtCell({
    required int gridColumns,
    required int gridRows,
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required Map<String, String> occupancyByCell,
    required Map<String, LayoutEditItem> itemsById,
  }) {
    return resolveDrop(
          gridColumns: gridColumns,
          gridRows: gridRows,
          movingId: movingId,
          hoverCol: hoverCol,
          hoverRow: hoverRow,
          occupancyByCell: occupancyByCell,
          itemsById: itemsById,
        ) !=
        null;
  }

  /// Returns `true` when [activeDragHover] changed and the widget should [setState].
  bool updateActiveDragHover({
    required RemoteLayoutResolvedDrop? resolved,
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required Map<String, LayoutEditItem> itemsById,
  }) {
    final movingPlacement = resolved?.movingPlacement;
    final canDrop = resolved != null;
    final anchor = dragAnchorForItem(movingId);
    final moving = itemsById[movingId];
    final fallbackFootprint = moving == null
        ? const RemoteLayoutItemFootprint(width: 1, height: 1)
        : RemoteLayoutEditorGridGeometry.validationFootprintFor(moving);
    final footprint = movingPlacement?.footprint ?? fallbackFootprint;
    final next = RemoteLayoutEditorActiveDragHover(
      movingId: movingId,
      hoverCol: hoverCol,
      hoverRow: hoverRow,
      snapCol: movingPlacement?.col ?? (hoverCol - anchor.colOffset),
      snapRow: movingPlacement?.row ?? (hoverRow - anchor.rowOffset),
      width: footprint.width,
      height: footprint.height,
      canDrop: canDrop,
    );
    final current = activeDragHover;
    if (current != null && current == next) {
      return false;
    }
    activeDragHover = next;
    return true;
  }

  bool cellInActiveFootprint(int col, int row) {
    final hover = activeDragHover;
    if (hover == null) {
      return false;
    }
    return col >= hover.snapCol &&
        col < hover.snapCol + hover.width &&
        row >= hover.snapRow &&
        row < hover.snapRow + hover.height;
  }

  void clearDragTracking() {
    isDraggingLayoutItem = false;
    activeDragHover = null;
  }

  /// Clears hover when the pointer leaves this cell; returns `true` if state changed.
  bool clearHoverOnLeaveCell(int col, int row) {
    final hover = activeDragHover;
    if (hover == null || hover.hoverCol != col || hover.hoverRow != row) {
      return false;
    }
    activeDragHover = null;
    return true;
  }

  void beginDragSession() {
    isDraggingLayoutItem = true;
    dragAcceptedInCurrentSession = false;
  }

  void markDropAccepted() {
    dragAcceptedInCurrentSession = true;
  }
}
