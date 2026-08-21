import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/domain/models/layout_zone.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_edit_grid_painter.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor_drag_session.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_header_icon_button.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor_grid_geometry.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor_item_preview.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_editor_metrics.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_header_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/theme/app_theme.dart';

/// Grid editor for per-device remote button positions.
///
/// Shares [layoutItems] with [RemoteHomePage] — **geometry is one source of truth**. Visuals here
/// (preview styles, borders, optional simplified or alternate widgets) may differ from the main
/// remote when that helps editing clarity.
///
/// Grid geometry lives in [RemoteLayoutEditorGridGeometry], background lines in
/// [RemoteLayoutEditGridPainter], cell previews in [RemoteLayoutEditorItemPreview], and drag/drop
/// state in [RemoteLayoutEditorDragSession].
class RemoteLayoutEditor extends StatefulWidget {
  const RemoteLayoutEditor({
    super.key,
    required this.layoutItems,
    required this.itemDefinitionsById,
    required this.gridColumns,
    required this.gridRows,
    required this.gridGap,
    required this.onResetLayout,
    required this.onPersistLayout,
  });

  final List<LayoutEditItem> layoutItems;
  final Map<String, RemoteLayoutItemDefinition> itemDefinitionsById;
  final int gridColumns;
  final int gridRows;
  final double gridGap;
  final Future<void> Function() onResetLayout;
  final Future<void> Function() onPersistLayout;

  @override
  State<RemoteLayoutEditor> createState() => _RemoteLayoutEditorState();
}

class _RemoteLayoutEditorState extends State<RemoteLayoutEditor> {
  final RemoteLayoutEditorDragSession _drag = RemoteLayoutEditorDragSession();
  final ScrollController _drawerScrollController = ScrollController();
  Timer? _drawerAutoScrollTimer;

  @override
  void dispose() {
    _drawerAutoScrollTimer?.cancel();
    _drawerScrollController.dispose();
    super.dispose();
  }

  /// All items by id, grid and drawer alike — drops need to look up drawer items too, or a
  /// drawer→grid drag could never resolve. Occupancy is the grid-only concern; see `gridItems`.
  Map<String, LayoutEditItem> get _itemsById => {
    for (final item in widget.layoutItems) item.id: item,
  };

  void _moveItemToZone(String itemId, LayoutZone zone) {
    final item = _itemsById[itemId];
    if (item == null || item.zone == zone) {
      return;
    }
    setState(() {
      item.zone = zone;
      _drag.markDropAccepted();
    });
    unawaited(widget.onPersistLayout());
  }

  /// One draggable item preview, shared by the grid canvas and the drawer strip.
  ///
  /// [cellSize] differs by caller: the grid's dynamically-fitted cell size, or the drawer's
  /// fixed [kRemoteLayoutDrawerItemCellSize] — everything else about drag wiring is identical
  /// regardless of which zone the item is currently in. The drawer strip scrolls via its own
  /// left/right triangle buttons (a separate touch target from these items), so items stay
  /// instant-drag like the grid — no long-press-to-distinguish-from-scroll needed.
  Widget _buildDraggableItemPreview({
    required LayoutEditItem item,
    required double cellSize,
  }) {
    return IgnorePointer(
      ignoring: _drag.isDraggingLayoutItem,
      child: Draggable<String>(
        data: item.id,
        onDragStarted: () {
          if (_drag.isDraggingLayoutItem) {
            return;
          }
          setState(_drag.beginDragSession);
        },
        onDragEnd: (_) {
          if (!mounted) {
            return;
          }
          if (!_drag.isDraggingLayoutItem) {
            return;
          }
          setState(_drag.clearDragTracking);
        },
        onDraggableCanceled: (velocity, offset) {
          if (!mounted) {
            return;
          }
          setState(_drag.clearDragTracking);
        },
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.85,
            child: RemoteLayoutEditorItemPreview(
              item: item,
              cellSize: cellSize,
              gridGap: widget.gridGap,
              itemDefinitionsById: widget.itemDefinitionsById,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: RemoteLayoutEditorItemPreview(
            item: item,
            cellSize: cellSize,
            gridGap: widget.gridGap,
            itemDefinitionsById: widget.itemDefinitionsById,
          ),
        ),
        child: Listener(
          onPointerDown: (event) {
            _drag.recordDragAnchor(
              item: item,
              localPosition: event.localPosition,
              cellSize: cellSize,
              gridGap: widget.gridGap,
            );
          },
          child: RemoteLayoutEditorItemPreview(
            item: item,
            cellSize: cellSize,
            gridGap: widget.gridGap,
            itemDefinitionsById: widget.itemDefinitionsById,
          ),
        ),
      ),
    );
  }

  /// Renders the grid canvas at a [cellSize]/[gridWidth] already resolved by [build] — computed
  /// once, up front, so the drawer strip below can be sized to the exact same [gridWidth].
  Widget _buildLayoutGridCanvas({
    required double cellSize,
    required double gridWidth,
  }) {
    final gridHeight =
        (widget.gridRows * cellSize) + ((widget.gridRows - 1) * widget.gridGap);
    final gridItems = widget.layoutItems
        .where((item) => item.zone == LayoutZone.grid)
        .toList(growable: false);
    final occupancyByCell = RemoteLayoutEditorGridGeometry.occupancyByCell(
      gridItems,
    );
    final itemsById = _itemsById;

    final appColors = AppTheme.colorsOf(context);
    final gridLineColor = appColors.remoteOutline.withValues(alpha: 0);
    final slotFillColor = appColors.remoteSurface.withValues(alpha: 0.82);
    final slotBorderColor = appColors.remoteOutline;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: gridWidth,
        height: gridHeight,
        child: Stack(
          children: [
            IgnorePointer(
              child: CustomPaint(
                size: Size(gridWidth, gridHeight),
                painter: RemoteLayoutEditGridPainter(
                  columns: widget.gridColumns,
                  rows: widget.gridRows,
                  cellSize: cellSize,
                  gap: widget.gridGap,
                  lineColor: gridLineColor,
                ),
              ),
            ),
            for (var row = 0; row < widget.gridRows; row++)
              for (var col = 0; col < widget.gridColumns; col++)
                Positioned(
                  left: col * (cellSize + widget.gridGap),
                  top: row * (cellSize + widget.gridGap),
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (details) {
                      return _drag.willAcceptDropAtCell(
                        gridColumns: widget.gridColumns,
                        gridRows: widget.gridRows,
                        movingId: details.data,
                        hoverCol: col,
                        hoverRow: row,
                        occupancyByCell: occupancyByCell,
                        itemsById: itemsById,
                      );
                    },
                    onMove: (details) {
                      final resolved = _drag.resolveDrop(
                        gridColumns: widget.gridColumns,
                        gridRows: widget.gridRows,
                        movingId: details.data,
                        hoverCol: col,
                        hoverRow: row,
                        occupancyByCell: occupancyByCell,
                        itemsById: itemsById,
                      );
                      if (_drag.updateActiveDragHover(
                        resolved: resolved,
                        movingId: details.data,
                        hoverCol: col,
                        hoverRow: row,
                        itemsById: itemsById,
                      )) {
                        setState(() {});
                      }
                    },
                    onLeave: (_) {
                      if (_drag.clearHoverOnLeaveCell(col, row)) {
                        setState(() {});
                      }
                    },
                    onAcceptWithDetails: (details) {
                      final resolved = _drag.resolveDrop(
                        gridColumns: widget.gridColumns,
                        gridRows: widget.gridRows,
                        movingId: details.data,
                        hoverCol: col,
                        hoverRow: row,
                        occupancyByCell: occupancyByCell,
                        itemsById: itemsById,
                      );
                      if (resolved == null) {
                        return;
                      }
                      setState(() {
                        resolved.movingPlacement.item.col =
                            resolved.movingPlacement.col;
                        resolved.movingPlacement.item.row =
                            resolved.movingPlacement.row;
                        resolved.movingPlacement.item.zone = LayoutZone.grid;
                        final displaced = resolved.displacedPlacement;
                        if (displaced != null) {
                          displaced.item.col = displaced.col;
                          displaced.item.row = displaced.row;
                        }
                        _drag.markDropAccepted();
                      });
                      unawaited(widget.onPersistLayout());
                    },
                    builder: (context, candidateData, _) {
                      final footprintHover = _drag.cellInActiveFootprint(
                        col,
                        row,
                      );
                      final hoverCanDrop =
                          _drag.activeDragHover?.canDrop ?? false;
                      final directTarget = candidateData.isNotEmpty;
                      final highlightDrop = directTarget || footprintHover;
                      final borderColor = !highlightDrop
                          ? slotBorderColor
                          : (hoverCanDrop
                                ? appColors.layoutEditorDropValid
                                : appColors.layoutEditorDropInvalid);
                      final borderWidth = highlightDrop ? 2.0 : 1.0;
                      return SizedBox(
                        width: cellSize,
                        height: cellSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: highlightDrop
                                ? slotFillColor.withValues(
                                    alpha: hoverCanDrop ? 0.9 : 0.72,
                                  )
                                : slotFillColor,
                            border: Border.all(
                              color: borderColor,
                              width: borderWidth,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            for (final item in gridItems)
              Positioned(
                left: item.col * (cellSize + widget.gridGap),
                top: item.row * (cellSize + widget.gridGap),
                child: _buildDraggableItemPreview(
                  item: item,
                  cellSize: cellSize,
                ),
              ),
          ],
        ),
      ),
    );
  }

  double get _drawerScrollIncrement =>
      kRemoteLayoutDrawerItemCellSize + widget.gridGap;

  void _scrollDrawerBy(double delta) {
    if (!_drawerScrollController.hasClients) {
      return;
    }
    final position = _drawerScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    unawaited(
      _drawerScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }

  void _startDrawerAutoScroll(double direction) {
    _drawerAutoScrollTimer?.cancel();
    final step = direction.sign * kRemoteLayoutDrawerAutoScrollPixelsPerTick;
    _drawerAutoScrollTimer = Timer.periodic(
      kRemoteLayoutDrawerAutoScrollTickInterval,
      (_) {
        if (!_drawerScrollController.hasClients) {
          return;
        }
        final position = _drawerScrollController.position;
        final target = (position.pixels + step).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        _drawerScrollController.jumpTo(target);
      },
    );
  }

  void _stopDrawerAutoScroll() {
    _drawerAutoScrollTimer?.cancel();
    _drawerAutoScrollTimer = null;
  }

  /// One tap scrolls by [_drawerScrollIncrement] (one item); holding scrolls continuously via
  /// [_startDrawerAutoScroll] until released.
  Widget _buildDrawerScrollButton({
    required IconData icon,
    required double scrollDirection,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          _scrollDrawerBy(scrollDirection.sign * _drawerScrollIncrement),
      onLongPressStart: (_) => _startDrawerAutoScroll(scrollDirection),
      onLongPressEnd: (_) => _stopDrawerAutoScroll(),
      onLongPressCancel: _stopDrawerAutoScroll,
      child: SizedBox(
        width: kRemoteLayoutDrawerChevronSize,
        height: kRemoteLayoutDrawerStripHeight,
        child: Icon(icon, size: kRemoteLayoutDrawerChevronSize * 0.7),
      ),
    );
  }

  Widget _buildDrawerStrip({required double gridWidth}) {
    final drawerItems = widget.layoutItems
        .where((item) => item.zone == LayoutZone.drawer)
        .toList(growable: false);
    final appColors = AppTheme.colorsOf(context);
    final boxWidth = math.max(
      0.0,
      gridWidth -
          2 * (kRemoteLayoutDrawerChevronSize + kRemoteLayoutDrawerChevronGap),
    );

    final box = DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          _itemsById[details.data]?.zone == LayoutZone.grid,
      onAcceptWithDetails: (details) =>
          _moveItemToZone(details.data, LayoutZone.drawer),
      builder: (context, candidateData, _) {
        final highlightDrop = candidateData.isNotEmpty;
        return Container(
          width: boxWidth,
          height: kRemoteLayoutDrawerStripHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: highlightDrop
                ? appColors.layoutEditorDropValid.withValues(alpha: 0.18)
                : appColors.remoteSurface.withValues(alpha: 0.5),
            border: Border.all(
              color: highlightDrop
                  ? appColors.layoutEditorDropValid
                  : appColors.remoteOutline,
              width: highlightDrop ? 2.0 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: drawerItems.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.layoutEditorDrawerEmptyHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.separated(
                  controller: _drawerScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: drawerItems.length,
                  separatorBuilder: (_, _) => SizedBox(width: widget.gridGap),
                  itemBuilder: (context, index) {
                    final item = drawerItems[index];
                    return Center(
                      child: _buildDraggableItemPreview(
                        item: item,
                        cellSize: kRemoteLayoutDrawerItemCellSize,
                      ),
                    );
                  },
                ),
        );
      },
    );

    return SizedBox(
      width: gridWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDrawerScrollButton(icon: Icons.arrow_left, scrollDirection: -1),
          const SizedBox(width: kRemoteLayoutDrawerChevronGap),
          box,
          const SizedBox(width: kRemoteLayoutDrawerChevronGap),
          _buildDrawerScrollButton(icon: Icons.arrow_right, scrollDirection: 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeightForGrid =
            constraints.maxHeight -
            kRemoteLayoutHeaderHeight -
            (2 * kRemoteLayoutDrawerStripSpacing) -
            kRemoteLayoutDrawerStripHeight;
        final cellSize = RemoteLayoutEditorGridGeometry.fitCellSize(
          gridColumns: widget.gridColumns,
          gridRows: widget.gridRows,
          gridGap: widget.gridGap,
          maxWidth: constraints.maxWidth,
          maxHeight: availableHeightForGrid,
        );
        final gridWidth =
            (widget.gridColumns * cellSize) +
            ((widget.gridColumns - 1) * widget.gridGap);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: kRemoteLayoutHeaderHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.layoutEditorTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      RemoteHeaderIconButton(
                        icon: Icons.restart_alt,
                        tooltip: AppLocalizations.of(
                          context,
                        )!.layoutEditorResetButton,
                        onPressed: () => unawaited(widget.onResetLayout()),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: kRemoteLayoutEditorInstructionTopSpacing,
                  ),
                  Text(
                    AppLocalizations.of(context)!.layoutEditorInstruction,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: kRemoteLayoutDrawerStripSpacing),
            Align(
              alignment: Alignment.topCenter,
              child: _buildDrawerStrip(gridWidth: gridWidth),
            ),
            const SizedBox(height: kRemoteLayoutDrawerStripSpacing),
            Expanded(
              child: _buildLayoutGridCanvas(
                cellSize: cellSize,
                gridWidth: gridWidth,
              ),
            ),
          ],
        );
      },
    );
  }
}
