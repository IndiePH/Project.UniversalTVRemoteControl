import 'package:one_remote/src/features/remote_control/presentation/widgets/layout_edit_item.dart';

/// Width/height used for hit-testing and placement checks in the layout editor grid.
///
/// May differ from [LayoutEditItem.width]/[LayoutEditItem.height] (e.g. dpad, volume/channel).
class RemoteLayoutItemFootprint {
  const RemoteLayoutItemFootprint({required this.width, required this.height});

  final int width;
  final int height;
}

/// One item’s resolved top-left cell and footprint for a drop or swap.
class RemoteLayoutItemPlacement {
  const RemoteLayoutItemPlacement({
    required this.item,
    required this.col,
    required this.row,
    required this.footprint,
  });

  final LayoutEditItem item;
  final int col;
  final int row;
  final RemoteLayoutItemFootprint footprint;
}

/// Outcome of resolving where the dragged item (and optional swap partner) land.
class RemoteLayoutResolvedDrop {
  const RemoteLayoutResolvedDrop({
    required this.movingPlacement,
    this.displacedPlacement,
  });

  final RemoteLayoutItemPlacement movingPlacement;
  final RemoteLayoutItemPlacement? displacedPlacement;
}

/// Pure grid logic for drag/drop: overlap detection, atomic validity, and swap resolution.
///
/// Keeps [RemoteLayoutEditor] focused on presentation and gesture wiring.
class RemoteLayoutDropResolver {
  RemoteLayoutDropResolver(this.validationFootprintFor);

  /// Same rules as the editor: dpad/channel/volume overrides, else item dimensions.
  final RemoteLayoutItemFootprint Function(LayoutEditItem item) validationFootprintFor;

  String _cellKey(int col, int row) => '$col:$row';

  bool _fitsInGrid({
    required int col,
    required int row,
    required RemoteLayoutItemFootprint footprint,
    required int gridColumns,
    required int gridRows,
  }) {
    if (col < 0 || row < 0) {
      return false;
    }
    if (col + footprint.width > gridColumns || row + footprint.height > gridRows) {
      return false;
    }
    return true;
  }

  bool _isAtomicPlacementValid({
    required List<RemoteLayoutItemPlacement> placements,
    required Map<String, String> occupancyByCell,
    required int gridColumns,
    required int gridRows,
  }) {
    final placedIds = <String>{for (final placement in placements) placement.item.id};
    final finalCells = <String, String>{};

    for (final placement in placements) {
      if (!_fitsInGrid(
        col: placement.col,
        row: placement.row,
        footprint: placement.footprint,
        gridColumns: gridColumns,
        gridRows: gridRows,
      )) {
        return false;
      }

      for (var row = placement.row; row < placement.row + placement.footprint.height; row++) {
        for (var col = placement.col; col < placement.col + placement.footprint.width; col++) {
          final key = _cellKey(col, row);
          final existingPlacedId = finalCells[key];
          if (existingPlacedId != null && existingPlacedId != placement.item.id) {
            return false;
          }
          finalCells[key] = placement.item.id;
        }
      }
    }

    for (final entry in finalCells.entries) {
      final occupantId = occupancyByCell[entry.key];
      if (occupantId == null || placedIds.contains(occupantId)) {
        continue;
      }
      return false;
    }
    return true;
  }

  Set<String> _overlappedItemIds({
    required int col,
    required int row,
    required RemoteLayoutItemFootprint footprint,
    required Map<String, String> occupancyByCell,
    Set<String> ignoreIds = const {},
  }) {
    final overlapped = <String>{};
    for (var targetRow = row; targetRow < row + footprint.height; targetRow++) {
      for (var targetCol = col; targetCol < col + footprint.width; targetCol++) {
        final occupyingId = occupancyByCell[_cellKey(targetCol, targetRow)];
        if (occupyingId == null || ignoreIds.contains(occupyingId)) {
          continue;
        }
        overlapped.add(occupyingId);
      }
    }
    return overlapped;
  }

  List<({int col, int row})> _edgeAdjacentOrigins({
    required int anchorCol,
    required int anchorRow,
    required int anchorWidth,
    required int anchorHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    final origins = <({int col, int row})>[];

    // Left / right neighbors: share vertical overlap.
    final minRow = anchorRow - targetHeight + 1;
    final maxRow = anchorRow + anchorHeight - 1;
    for (var row = minRow; row <= maxRow; row++) {
      origins.add((col: anchorCol - targetWidth, row: row));
      origins.add((col: anchorCol + anchorWidth, row: row));
    }

    // Top / bottom neighbors: share horizontal overlap.
    final minCol = anchorCol - targetWidth + 1;
    final maxCol = anchorCol + anchorWidth - 1;
    for (var col = minCol; col <= maxCol; col++) {
      origins.add((col: col, row: anchorRow - targetHeight));
      origins.add((col: col, row: anchorRow + anchorHeight));
    }

    return origins;
  }

  int _directionalSideRank({
    required int candidateCol,
    required int candidateRow,
    required int targetWidth,
    required int targetHeight,
    required int anchorCol,
    required int anchorRow,
    required int anchorWidth,
    required int anchorHeight,
    required int preferredColDir,
    required int preferredRowDir,
  }) {
    var sideColDir = 0;
    var sideRowDir = 0;
    if (candidateRow + targetHeight <= anchorRow) {
      sideRowDir = -1; // above
    } else if (candidateRow >= anchorRow + anchorHeight) {
      sideRowDir = 1; // below
    } else if (candidateCol + targetWidth <= anchorCol) {
      sideColDir = -1; // left
    } else if (candidateCol >= anchorCol + anchorWidth) {
      sideColDir = 1; // right
    }

    if (preferredRowDir != 0) {
      if (sideRowDir == preferredRowDir) {
        return 0; // toward original direction
      }
      if (sideRowDir == -preferredRowDir) {
        return 1; // opposite direction
      }
      return 2; // other adjacent sides
    }
    if (preferredColDir != 0) {
      if (sideColDir == preferredColDir) {
        return 0; // toward original direction
      }
      if (sideColDir == -preferredColDir) {
        return 1; // opposite direction
      }
      return 2; // other adjacent sides
    }
    return 0;
  }

  /// Keeps moving at dropped position and resolves displaced target using full-footprint candidates.
  /// Returns the first atomically valid swap pair or null.
  RemoteLayoutResolvedDrop? _resolveFootprintAwareSwap({
    required RemoteLayoutItemPlacement movingDropPlacement,
    required LayoutEditItem target,
    required RemoteLayoutItemFootprint targetFootprint,
    required LayoutEditItem moving,
    required Map<String, String> occupancyByCell,
    required int gridColumns,
    required int gridRows,
  }) {
    final seen = <String>{};
    final candidates = <({int col, int row, int priority, int sideRank, int distance})>[];

    final preferredColDir = (moving.col - movingDropPlacement.col).sign;
    final preferredRowDir = (moving.row - movingDropPlacement.row).sign;

    void addCandidate({
      required int col,
      required int row,
      required int priority,
      required int sideRank,
    }) {
      final key = _cellKey(col, row);
      if (!seen.add(key)) {
        return;
      }
      final distance = (col - target.col).abs() + (row - target.row).abs();
      candidates.add(
        (
          col: col,
          row: row,
          priority: priority,
          sideRank: sideRank,
          distance: distance,
        ),
      );
    }

    // 1) Preserve old simple behavior first.
    addCandidate(col: moving.col, row: moving.row, priority: 0, sideRank: 0);

    // 2) Candidates adjacent to moved footprint.
    final aroundFinal = _edgeAdjacentOrigins(
      anchorCol: movingDropPlacement.col,
      anchorRow: movingDropPlacement.row,
      anchorWidth: movingDropPlacement.footprint.width,
      anchorHeight: movingDropPlacement.footprint.height,
      targetWidth: targetFootprint.width,
      targetHeight: targetFootprint.height,
    );
    for (final c in aroundFinal) {
      addCandidate(
        col: c.col,
        row: c.row,
        priority: 1,
        sideRank: _directionalSideRank(
          candidateCol: c.col,
          candidateRow: c.row,
          targetWidth: targetFootprint.width,
          targetHeight: targetFootprint.height,
          anchorCol: movingDropPlacement.col,
          anchorRow: movingDropPlacement.row,
          anchorWidth: movingDropPlacement.footprint.width,
          anchorHeight: movingDropPlacement.footprint.height,
          preferredColDir: preferredColDir,
          preferredRowDir: preferredRowDir,
        ),
      );
    }

    // 3) Candidates adjacent to moving's original footprint.
    final aroundInitial = _edgeAdjacentOrigins(
      anchorCol: moving.col,
      anchorRow: moving.row,
      anchorWidth: movingDropPlacement.footprint.width,
      anchorHeight: movingDropPlacement.footprint.height,
      targetWidth: targetFootprint.width,
      targetHeight: targetFootprint.height,
    );
    for (final c in aroundInitial) {
      addCandidate(
        col: c.col,
        row: c.row,
        priority: 2,
        sideRank: 0,
      );
    }

    candidates.sort((a, b) {
      final p = a.priority.compareTo(b.priority);
      if (p != 0) {
        return p;
      }
      final s = a.sideRank.compareTo(b.sideRank);
      if (s != 0) {
        return s;
      }
      return a.distance.compareTo(b.distance);
    });

    for (final c in candidates) {
      final displaced = RemoteLayoutItemPlacement(
        item: target,
        col: c.col,
        row: c.row,
        footprint: targetFootprint,
      );
      final valid = _isAtomicPlacementValid(
        placements: <RemoteLayoutItemPlacement>[movingDropPlacement, displaced],
        occupancyByCell: occupancyByCell,
        gridColumns: gridColumns,
        gridRows: gridRows,
      );
      if (!valid) {
        continue;
      }
      return RemoteLayoutResolvedDrop(
        movingPlacement: movingDropPlacement,
        displacedPlacement: displaced,
      );
    }
    return null;
  }

  String _formatSize(RemoteLayoutItemFootprint footprint) {
    return '${footprint.width}x${footprint.height}';
  }

  String _formatPos({required int col, required int row}) {
    return '(col:$col,row:$row)';
  }

  String _formatItemSnapshot({
    required String id,
    required int col,
    required int row,
    required RemoteLayoutItemFootprint footprint,
  }) {
    return '$id@${_formatPos(col: col, row: row)} size=${_formatSize(footprint)}';
  }

  String _buildInitialLayoutSnapshot(Map<String, LayoutEditItem> itemsById) {
    final sortedIds = itemsById.keys.toList()..sort();
    return sortedIds
        .map((id) {
          final item = itemsById[id]!;
          return _formatItemSnapshot(
            id: item.id,
            col: item.col,
            row: item.row,
            footprint: validationFootprintFor(item),
          );
        })
        .join(' | ');
  }

  /// Builds a paste-ready debug dump for one accepted drag/drop operation.
  String buildOperationDebugLog({
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required int anchorColOffset,
    required int anchorRowOffset,
    required Map<String, String> occupancyByCell,
    required Map<String, LayoutEditItem> itemsById,
    required RemoteLayoutResolvedDrop resolved,
  }) {
    final moving = itemsById[movingId];
    if (moving == null) {
      return 'DragDrop Debug\nerror: moving item "$movingId" not found';
    }

    final movingFootprint = validationFootprintFor(moving);
    final dropCol = hoverCol - anchorColOffset;
    final dropRow = hoverRow - anchorRowOffset;
    final dropPlacement = RemoteLayoutItemPlacement(
      item: moving,
      col: dropCol,
      row: dropRow,
      footprint: movingFootprint,
    );

    final overlapCellsById = <String, List<({int col, int row})>>{};
    final occupancyAtDropCells = <String>[];
    for (var row = dropPlacement.row; row < dropPlacement.row + dropPlacement.footprint.height; row++) {
      for (var col = dropPlacement.col; col < dropPlacement.col + dropPlacement.footprint.width; col++) {
        final key = _cellKey(col, row);
        final occupantId = occupancyByCell[key];
        occupancyAtDropCells.add(
          '${_formatPos(col: col, row: row)}=${occupantId ?? 'empty'}',
        );
        if (occupantId == null || occupantId == movingId) {
          continue;
        }
        overlapCellsById.putIfAbsent(occupantId, () => <({int col, int row})>[]).add((
          col: col,
          row: row,
        ));
      }
    }

    LayoutEditItem? target;
    if (resolved.displacedPlacement != null) {
      target = resolved.displacedPlacement!.item;
    } else if (overlapCellsById.length == 1) {
      target = itemsById[overlapCellsById.keys.first];
    }

    final targetInitialPos = target == null
        ? 'n/a'
        : _formatPos(col: target.col, row: target.row);
    final targetSize = target == null ? 'n/a' : _formatSize(validationFootprintFor(target));
    final targetFinalPos = resolved.displacedPlacement == null
        ? 'n/a'
        : _formatPos(
            col: resolved.displacedPlacement!.col,
            row: resolved.displacedPlacement!.row,
          );

    final overlapSummary = overlapCellsById.isEmpty
        ? 'none'
        : overlapCellsById.entries.map((entry) {
            final targetItem = itemsById[entry.key];
            final targetTop = targetItem?.row;
            final targetLeft = targetItem?.col;
            final cells = entry.value.map((c) {
              if (targetTop == null || targetLeft == null) {
                return _formatPos(col: c.col, row: c.row);
              }
              final relativeCol = (c.col - targetLeft) + 1;
              final relativeRow = (c.row - targetTop) + 1;
              return '${_formatPos(col: c.col, row: c.row)} [targetCell:$relativeCol,$relativeRow]';
            }).join(', ');
            return '${entry.key}: $cells';
          }).join(' | ');

    final sortedIds = itemsById.keys.toList()..sort();
    final initialLayout = _buildInitialLayoutSnapshot(itemsById);

    final finalColById = <String, int>{};
    final finalRowById = <String, int>{};
    finalColById[resolved.movingPlacement.item.id] = resolved.movingPlacement.col;
    finalRowById[resolved.movingPlacement.item.id] = resolved.movingPlacement.row;
    final displaced = resolved.displacedPlacement;
    if (displaced != null) {
      finalColById[displaced.item.id] = displaced.col;
      finalRowById[displaced.item.id] = displaced.row;
    }
    final finalLayout = sortedIds
        .map((id) {
          final item = itemsById[id]!;
          return _formatItemSnapshot(
            id: item.id,
            col: finalColById[id] ?? item.col,
            row: finalRowById[id] ?? item.row,
            footprint: validationFootprintFor(item),
          );
        })
        .join(' | ');

    return [
      'DragDrop Debug',
      'dropCell=${_formatPos(col: hoverCol, row: hoverRow)} anchor=(colOffset:$anchorColOffset,rowOffset:$anchorRowOffset)',
      'moving.id=${moving.id}',
      'moving.size=${_formatSize(movingFootprint)}',
      'moving.initial=${_formatPos(col: moving.col, row: moving.row)}',
      'moving.dropped=${_formatPos(col: dropCol, row: dropRow)}',
      'moving.final=${_formatPos(col: resolved.movingPlacement.col, row: resolved.movingPlacement.row)}',
      'target.id=${target?.id ?? 'n/a'}',
      'target.size=$targetSize',
      'target.initial=$targetInitialPos',
      'target.final=$targetFinalPos',
      'occupancyAtDrop=${occupancyAtDropCells.join(', ')}',
      'overlapsAtDrop=$overlapSummary',
      'layout.initial=$initialLayout',
      'layout.final=$finalLayout',
    ].join('\n');
  }

  String _diagnoseDropFailureReason({
    required int gridColumns,
    required int gridRows,
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required Map<String, String> occupancyByCell,
    required Map<String, LayoutEditItem> itemsById,
    required int anchorColOffset,
    required int anchorRowOffset,
  }) {
    final moving = itemsById[movingId];
    if (moving == null) {
      return 'moving_not_found';
    }
    final movingFootprint = validationFootprintFor(moving);
    final dropCol = hoverCol - anchorColOffset;
    final dropRow = hoverRow - anchorRowOffset;
    final movingDropPlacement = RemoteLayoutItemPlacement(
      item: moving,
      col: dropCol,
      row: dropRow,
      footprint: movingFootprint,
    );
    if (!_fitsInGrid(
      col: movingDropPlacement.col,
      row: movingDropPlacement.row,
      footprint: movingDropPlacement.footprint,
      gridColumns: gridColumns,
      gridRows: gridRows,
    )) {
      return 'drop_out_of_bounds';
    }
    final overlappedIds = _overlappedItemIds(
      col: movingDropPlacement.col,
      row: movingDropPlacement.row,
      footprint: movingDropPlacement.footprint,
      occupancyByCell: occupancyByCell,
      ignoreIds: {moving.id},
    );
    if (overlappedIds.isEmpty) {
      final valid = _isAtomicPlacementValid(
        placements: <RemoteLayoutItemPlacement>[movingDropPlacement],
        occupancyByCell: occupancyByCell,
        gridColumns: gridColumns,
        gridRows: gridRows,
      );
      return valid ? 'none' : 'single_move_invalid';
    }
    if (overlappedIds.length > 1) {
      return 'overlap_multiple_targets';
    }
    final target = itemsById[overlappedIds.first];
    if (target == null) {
      return 'target_missing';
    }
    final targetFootprint = validationFootprintFor(target);
    final resolvedSwap = _resolveFootprintAwareSwap(
      movingDropPlacement: movingDropPlacement,
      target: target,
      targetFootprint: targetFootprint,
      moving: moving,
      occupancyByCell: occupancyByCell,
      gridColumns: gridColumns,
      gridRows: gridRows,
    );
    return resolvedSwap != null ? 'none' : 'simple_swap_invalid';
  }

  /// Public wrapper used by UI to show user-facing failed-drop reasons.
  String diagnoseDropFailureReason({
    required int gridColumns,
    required int gridRows,
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required Map<String, String> occupancyByCell,
    required Map<String, LayoutEditItem> itemsById,
    required int anchorColOffset,
    required int anchorRowOffset,
  }) {
    return _diagnoseDropFailureReason(
      gridColumns: gridColumns,
      gridRows: gridRows,
      movingId: movingId,
      hoverCol: hoverCol,
      hoverRow: hoverRow,
      occupancyByCell: occupancyByCell,
      itemsById: itemsById,
      anchorColOffset: anchorColOffset,
      anchorRowOffset: anchorRowOffset,
    );
  }

  String describeFailureReason(String reasonCode) {
    switch (reasonCode) {
      case 'moving_not_found':
        return 'Dragged button was not found.';
      case 'drop_out_of_bounds':
        return 'Dropped position is out of bounds.';
      case 'single_move_invalid':
        return 'Drop overlaps another button.';
      case 'overlap_multiple_targets':
        return 'Drop overlaps multiple buttons.';
      case 'target_missing':
        return 'Swap target could not be resolved.';
      case 'simple_swap_invalid':
        return 'Simple swap is invalid because it overlaps other buttons.';
      case 'drop_not_accepted':
        return 'Drop was not accepted.';
      case 'drag_ended_without_target':
        return 'Drag ended outside any valid target.';
      case 'drag_canceled':
        return 'Drag was canceled.';
      case 'none':
        return 'No failure reason.';
      default:
        return 'Drop failed ($reasonCode).';
    }
  }

  /// Builds a paste-ready debug dump for a rejected drag/drop attempt.
  String buildRejectedOperationDebugLog({
    required int gridColumns,
    required int gridRows,
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required int anchorColOffset,
    required int anchorRowOffset,
    required Map<String, String> occupancyByCell,
    required Map<String, LayoutEditItem> itemsById,
  }) {
    final moving = itemsById[movingId];
    if (moving == null) {
      return [
        'DragDrop Debug',
        'result=rejected',
        'reason=moving_not_found',
        'moving.id=$movingId',
      ].join('\n');
    }

    final movingFootprint = validationFootprintFor(moving);
    final dropCol = hoverCol - anchorColOffset;
    final dropRow = hoverRow - anchorRowOffset;
    final dropPlacement = RemoteLayoutItemPlacement(
      item: moving,
      col: dropCol,
      row: dropRow,
      footprint: movingFootprint,
    );

    final occupancyAtDropCells = <String>[];
    final overlapCellsById = <String, List<({int col, int row})>>{};
    for (var row = dropPlacement.row; row < dropPlacement.row + dropPlacement.footprint.height; row++) {
      for (var col = dropPlacement.col; col < dropPlacement.col + dropPlacement.footprint.width; col++) {
        final occupantId = occupancyByCell[_cellKey(col, row)];
        occupancyAtDropCells.add('${_formatPos(col: col, row: row)}=${occupantId ?? 'empty'}');
        if (occupantId == null || occupantId == movingId) {
          continue;
        }
        overlapCellsById.putIfAbsent(occupantId, () => <({int col, int row})>[]).add((
          col: col,
          row: row,
        ));
      }
    }

    final overlapSummary = overlapCellsById.isEmpty
        ? 'none'
        : overlapCellsById.entries.map((entry) {
            final cells = entry.value
                .map((c) => _formatPos(col: c.col, row: c.row))
                .join(', ');
            return '${entry.key}: $cells';
          }).join(' | ');

    final reason = _diagnoseDropFailureReason(
      gridColumns: gridColumns,
      gridRows: gridRows,
      movingId: movingId,
      hoverCol: hoverCol,
      hoverRow: hoverRow,
      occupancyByCell: occupancyByCell,
      itemsById: itemsById,
      anchorColOffset: anchorColOffset,
      anchorRowOffset: anchorRowOffset,
    );

    return [
      'DragDrop Debug',
      'result=rejected',
      'reason=$reason',
      'dropCell=${_formatPos(col: hoverCol, row: hoverRow)} anchor=(colOffset:$anchorColOffset,rowOffset:$anchorRowOffset)',
      'moving.id=${moving.id}',
      'moving.size=${_formatSize(movingFootprint)}',
      'moving.initial=${_formatPos(col: moving.col, row: moving.row)}',
      'moving.dropped=${_formatPos(col: dropCol, row: dropRow)}',
      'occupancyAtDrop=${occupancyAtDropCells.join(', ')}',
      'overlapsAtDrop=$overlapSummary',
      'layout.initial=${_buildInitialLayoutSnapshot(itemsById)}',
    ].join('\n');
  }

  /// Resolves drop position for [movingId] given anchor-adjusted hover cell and current occupancy.
  RemoteLayoutResolvedDrop? resolveDrop({
    required int gridColumns,
    required int gridRows,
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required Map<String, String> occupancyByCell,
    required Map<String, LayoutEditItem> itemsById,
    required int anchorColOffset,
    required int anchorRowOffset,
  }) {
    final moving = itemsById[movingId];
    if (moving == null) {
      return null;
    }
    final movingFootprint = validationFootprintFor(moving);
    final dropCol = hoverCol - anchorColOffset;
    final dropRow = hoverRow - anchorRowOffset;
    final movingDropPlacement = RemoteLayoutItemPlacement(
      item: moving,
      col: dropCol,
      row: dropRow,
      footprint: movingFootprint,
    );

    if (!_fitsInGrid(
      col: movingDropPlacement.col,
      row: movingDropPlacement.row,
      footprint: movingDropPlacement.footprint,
      gridColumns: gridColumns,
      gridRows: gridRows,
    )) {
      return null;
    }

    final overlappedIds = _overlappedItemIds(
      col: movingDropPlacement.col,
      row: movingDropPlacement.row,
      footprint: movingDropPlacement.footprint,
      occupancyByCell: occupancyByCell,
      ignoreIds: {moving.id},
    );

    if (overlappedIds.isEmpty) {
      final valid = _isAtomicPlacementValid(
        placements: <RemoteLayoutItemPlacement>[movingDropPlacement],
        occupancyByCell: occupancyByCell,
        gridColumns: gridColumns,
        gridRows: gridRows,
      );
      return valid ? RemoteLayoutResolvedDrop(movingPlacement: movingDropPlacement) : null;
    }

    if (overlappedIds.length > 1) {
      return null;
    }

    final targetId = overlappedIds.first;
    final target = itemsById[targetId];
    if (target == null) {
      return null;
    }

    final targetFootprint = validationFootprintFor(target);

    final resolvedSwap = _resolveFootprintAwareSwap(
      movingDropPlacement: movingDropPlacement,
      target: target,
      targetFootprint: targetFootprint,
      moving: moving,
      occupancyByCell: occupancyByCell,
      gridColumns: gridColumns,
      gridRows: gridRows,
    );
    if (resolvedSwap == null) {
      return null;
    }
    return resolvedSwap;
  }
}
