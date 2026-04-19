import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_edit_grid_painter.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_editor_drag_session.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_editor_grid_geometry.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_editor_item_preview.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/src/theme/app_theme.dart';

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

  Widget _buildLayoutGridCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final cellSize = RemoteLayoutEditorGridGeometry.fitCellSize(
          gridColumns: widget.gridColumns,
          gridRows: widget.gridRows,
          gridGap: widget.gridGap,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
        final gridWidth =
            (widget.gridColumns * cellSize) + ((widget.gridColumns - 1) * widget.gridGap);
        final gridHeight =
            (widget.gridRows * cellSize) + ((widget.gridRows - 1) * widget.gridGap);
        final occupancyByCell =
            RemoteLayoutEditorGridGeometry.occupancyByCell(widget.layoutItems);
        final itemsById = <String, LayoutEditItem>{
          for (final item in widget.layoutItems) item.id: item,
        };

        final appColors = AppTheme.colorsOf(context);
        final gridLineColor = appColors.remoteOutline.withValues(alpha: 0.35);
        final slotFillColor = appColors.remoteSurface.withValues(alpha: 0.82);
        final slotBorderColor = appColors.remoteOutline;
        return Center(
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
                          final footprintHover = _drag.cellInActiveFootprint(col, row);
                          final hoverCanDrop = _drag.activeDragHover?.canDrop ?? false;
                          final directTarget = candidateData.isNotEmpty;
                          final highlightDrop = directTarget || footprintHover;
                          final borderColor = !highlightDrop
                              ? slotBorderColor
                              : (hoverCanDrop
                                  ? appColors.layoutEditorDropValid
                                  : appColors.layoutEditorDropInvalid);
                          final borderWidth = highlightDrop ? 2.0 : 1.0;
                          return Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: highlightDrop
                                  ? slotFillColor.withValues(
                                      alpha: hoverCanDrop ? 0.9 : 0.72,
                                    )
                                  : slotFillColor,
                              borderRadius: BorderRadius.circular(cellSize * 0.2),
                              border: Border.all(color: borderColor, width: borderWidth),
                            ),
                          );
                        },
                      ),
                    ),
                for (final item in widget.layoutItems)
                  Positioned(
                    left: item.col * (cellSize + widget.gridGap),
                    top: item.row * (cellSize + widget.gridGap),
                    child: IgnorePointer(
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
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Layout Editor',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => unawaited(widget.onResetLayout()),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Layout'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Drag buttons to new positions. Grid lines show cells; a green outline means the drop is allowed.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildLayoutGridCanvas()),
      ],
    );
  }
}
