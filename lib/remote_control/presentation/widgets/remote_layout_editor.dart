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
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_button_metrics.dart';
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

  /// All items by id, including drawer items (drops need to resolve those too). Built once per
  /// [build] and passed down, not recomputed per drag callback.
  Map<String, LayoutEditItem> _buildItemsById() => {
    for (final item in widget.layoutItems) item.id: item,
  };

  /// Shared setState + markDropAccepted + persist wiring for both drop paths; only the mutation
  /// itself differs between them.
  void _applyDropAndPersist(VoidCallback mutate) {
    setState(() {
      mutate();
      _drag.markDropAccepted();
    });
    unawaited(widget.onPersistLayout());
  }

  void _moveItemToZone(
    Map<String, LayoutEditItem> itemsById,
    String itemId,
    LayoutZone zone,
  ) {
    final item = itemsById[itemId];
    if (item == null || item.zone == zone) {
      return;
    }
    _applyDropAndPersist(() => item.zone = zone);
  }

  /// Draggable item preview shared by the grid and drawer. Drawer items stay instant-drag (no
  /// long-press) since the drawer scrolls via its own chevrons, not by dragging items.
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

  /// Renders the grid at the [cellSize]/[gridWidth] [build] already resolved, so the drawer
  /// strip can match [gridWidth] exactly.
  Widget _buildLayoutGridCanvas({
    required double cellSize,
    required double gridWidth,
    required Map<String, LayoutEditItem> itemsById,
  }) {
    final gridHeight =
        (widget.gridRows * cellSize) + ((widget.gridRows - 1) * widget.gridGap);
    final gridItems = widget.layoutItems
        .where((item) => item.zone == LayoutZone.grid)
        .toList(growable: false);
    final occupancyByCell = RemoteLayoutEditorGridGeometry.occupancyByCell(
      gridItems,
    );

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
                      _applyDropAndPersist(() {
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
                      });
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

  /// Scroll offset after moving by [delta], clamped to the scrollable range.
  double _clampedDrawerScrollTarget(double delta) {
    final position = _drawerScrollController.position;
    return (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  void _scrollDrawerBy(double delta) {
    if (!_drawerScrollController.hasClients) {
      return;
    }
    unawaited(
      _drawerScrollController.animateTo(
        _clampedDrawerScrollTarget(delta),
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
        _drawerScrollController.jumpTo(_clampedDrawerScrollTarget(step));
      },
    );
  }

  void _stopDrawerAutoScroll() {
    _drawerAutoScrollTimer?.cancel();
    _drawerAutoScrollTimer = null;
  }

  /// Tap scrolls by one cell width; holding auto-scrolls. (Multi-cell items like dpad take more
  /// than one tap to clear — accepted, see [kRemoteLayoutDrawerItemCellSize].) The outer
  /// [GestureDetector] handles the hold ([InkWell] has no hold-repeat callback); `triggerMode:
  /// manual` stops [Tooltip]'s own long-press from competing with it.
  Widget _buildDrawerScrollButton({
    required IconData icon,
    required String tooltip,
    required double scrollDirection,
  }) {
    final appColors = AppTheme.colorsOf(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: appColors.remoteOutline,
        width: kRemoteHeaderButtonBorderWidth,
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _startDrawerAutoScroll(scrollDirection),
      onLongPressEnd: (_) => _stopDrawerAutoScroll(),
      onLongPressCancel: _stopDrawerAutoScroll,
      child: Tooltip(
        message: tooltip,
        triggerMode: TooltipTriggerMode.manual,
        child: Material(
          color: appColors.remoteSurface,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: () =>
                _scrollDrawerBy(scrollDirection.sign * _drawerScrollIncrement),
            child: SizedBox(
              width: kRemoteLayoutDrawerChevronSize,
              height: kRemoteLayoutDrawerStripHeight,
              child: Icon(icon, size: kRemoteLayoutDrawerChevronSize * 0.7),
            ),
          ),
        ),
      ),
    );
  }

  /// Box matches [gridWidth] when there's room for the chevrons outside it; shrinks below that
  /// only on narrow screens where there isn't.
  Widget _buildDrawerStrip({
    required double gridWidth,
    required double maxWidth,
    required Map<String, LayoutEditItem> itemsById,
  }) {
    final drawerItems = widget.layoutItems
        .where((item) => item.zone == LayoutZone.drawer)
        .toList(growable: false);
    final appColors = AppTheme.colorsOf(context);
    final chevronBudget =
        2 * (kRemoteLayoutDrawerChevronSize + kRemoteLayoutDrawerChevronGap);
    final showChevrons = maxWidth >= chevronBudget;
    final boxWidth = math.min(
      gridWidth,
      showChevrons ? maxWidth - chevronBudget : maxWidth,
    );

    final box = DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          itemsById[details.data]?.zone == LayoutZone.grid,
      onAcceptWithDetails: (details) =>
          _moveItemToZone(itemsById, details.data, LayoutZone.drawer),
      builder: (context, candidateData, _) {
        final highlightDrop = candidateData.isNotEmpty;
        return Container(
          key: const ValueKey('drawerBox'),
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

    if (!showChevrons) {
      return box;
    }

    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDrawerScrollButton(
          icon: Icons.arrow_left,
          tooltip: l10n.layoutEditorDrawerScrollLeft,
          scrollDirection: -1,
        ),
        const SizedBox(width: kRemoteLayoutDrawerChevronGap),
        box,
        const SizedBox(width: kRemoteLayoutDrawerChevronGap),
        _buildDrawerScrollButton(
          icon: Icons.arrow_right,
          tooltip: l10n.layoutEditorDrawerScrollRight,
          scrollDirection: 1,
        ),
      ],
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
        final itemsById = _buildItemsById();

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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              child: _buildDrawerStrip(
                gridWidth: gridWidth,
                maxWidth: constraints.maxWidth,
                itemsById: itemsById,
              ),
            ),
            const SizedBox(height: kRemoteLayoutDrawerStripSpacing),
            Expanded(
              child: _buildLayoutGridCanvas(
                cellSize: cellSize,
                gridWidth: gridWidth,
                itemsById: itemsById,
              ),
            ),
          ],
        );
      },
    );
  }
}
