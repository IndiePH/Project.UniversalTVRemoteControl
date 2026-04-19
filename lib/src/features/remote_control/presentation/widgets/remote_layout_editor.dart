import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_drop_resolver.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_circular_dpad.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_icon_circle_button.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_vertical_rocker.dart';
import 'package:one_remote/src/theme/app_theme.dart';

void _noop() {}

/// Grid editor for per-device remote button positions.
///
/// Shares [layoutItems] with [RemoteHomePage] — **geometry is one source of truth**. Visuals here
/// (preview styles, borders, optional simplified or alternate widgets) may differ from the main
/// remote when that helps editing clarity.
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
  final Map<String, _DragAnchorOffset> _dragAnchorOffsetsByItemId =
      <String, _DragAnchorOffset>{};
  bool _isDraggingLayoutItem = false;
  _ActiveDragHover? _activeDragHover;
  bool _dragAcceptedInCurrentSession = false;
  _LastDragAttempt? _lastDragAttempt;

  RemoteLayoutItemFootprint _validationFootprintFor(LayoutEditItem item) {
    if (item.id == 'dpad') {
      return const RemoteLayoutItemFootprint(width: 3, height: 3);
    }
    if (item.id == 'volume' || item.id == 'channel') {
      return const RemoteLayoutItemFootprint(width: 1, height: 3);
    }
    return RemoteLayoutItemFootprint(width: item.width, height: item.height);
  }

  late final RemoteLayoutDropResolver _dropResolver =
      RemoteLayoutDropResolver(_validationFootprintFor);

  String _cellKey(int col, int row) => '$col:$row';

  Map<String, String> _buildOccupancyByCell(List<LayoutEditItem> items) {
    final occupancyByCell = <String, String>{};
    for (final item in items) {
      for (var row = item.row; row < item.row + item.height; row++) {
        for (var col = item.col; col < item.col + item.width; col++) {
          occupancyByCell[_cellKey(col, row)] = item.id;
        }
      }
    }
    return occupancyByCell;
  }

  void _recordDragAnchor({
    required LayoutEditItem item,
    required Offset localPosition,
    required double cellSize,
  }) {
    final footprint = _validationFootprintFor(item);
    final stride = cellSize + widget.gridGap;
    final colOffset = (localPosition.dx / stride).floor().clamp(
      0,
      footprint.width - 1,
    );
    final rowOffset = (localPosition.dy / stride).floor().clamp(
      0,
      footprint.height - 1,
    );
    _dragAnchorOffsetsByItemId[item.id] = _DragAnchorOffset(
      colOffset: colOffset,
      rowOffset: rowOffset,
    );
  }

  _DragAnchorOffset _dragAnchorForItem(String itemId) {
    return _dragAnchorOffsetsByItemId[itemId] ??
        const _DragAnchorOffset(colOffset: 0, rowOffset: 0);
  }

  RemoteLayoutResolvedDrop? _resolveDrop({
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required Map<String, String> occupancyByCell,
    required Map<String, LayoutEditItem> itemsById,
  }) {
    final anchor = _dragAnchorForItem(movingId);
    return _dropResolver.resolveDrop(
      gridColumns: widget.gridColumns,
      gridRows: widget.gridRows,
      movingId: movingId,
      hoverCol: hoverCol,
      hoverRow: hoverRow,
      occupancyByCell: occupancyByCell,
      itemsById: itemsById,
      anchorColOffset: anchor.colOffset,
      anchorRowOffset: anchor.rowOffset,
    );
  }

  /// Same rules as [DragTarget.onWillAcceptWithDetails] — used for drop-target highlights.
  bool _willAcceptDropAtCell({
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required Map<String, String> occupancyByCell,
    required Map<String, LayoutEditItem> itemsById,
  }) {
    final resolved = _resolveDrop(
      movingId: movingId,
      hoverCol: hoverCol,
      hoverRow: hoverRow,
      occupancyByCell: occupancyByCell,
      itemsById: itemsById,
    );
    return resolved != null;
  }

  void _clearDragTracking() {
    _isDraggingLayoutItem = false;
    _activeDragHover = null;
  }

  void _updateActiveDragHover({
    required RemoteLayoutResolvedDrop? resolved,
    required String movingId,
    required int hoverCol,
    required int hoverRow,
    required Map<String, LayoutEditItem> itemsById,
  }) {
    final movingPlacement = resolved?.movingPlacement;
    final canDrop = resolved != null;
    final anchor = _dragAnchorForItem(movingId);
    final moving = itemsById[movingId];
    final fallbackFootprint = moving == null
        ? const RemoteLayoutItemFootprint(width: 1, height: 1)
        : _validationFootprintFor(moving);
    final footprint = movingPlacement?.footprint ?? fallbackFootprint;
    final next = _ActiveDragHover(
      movingId: movingId,
      hoverCol: hoverCol,
      hoverRow: hoverRow,
      snapCol: movingPlacement?.col ?? (hoverCol - anchor.colOffset),
      snapRow: movingPlacement?.row ?? (hoverRow - anchor.rowOffset),
      width: footprint.width,
      height: footprint.height,
      canDrop: canDrop,
    );
    final current = _activeDragHover;
    if (current != null && current == next) {
      return;
    }
    setState(() {
      _activeDragHover = next;
    });
  }

  bool _cellInActiveFootprint(int col, int row) {
    final hover = _activeDragHover;
    if (hover == null) {
      return false;
    }
    return col >= hover.snapCol &&
        col < hover.snapCol + hover.width &&
        row >= hover.snapRow &&
        row < hover.snapRow + hover.height;
  }

  double _fitCellSize({required double maxWidth, required double maxHeight}) {
    final widthLimited =
        (maxWidth - ((widget.gridColumns - 1) * widget.gridGap)) / widget.gridColumns;
    final heightLimited =
        (maxHeight - ((widget.gridRows - 1) * widget.gridGap)) / widget.gridRows;
    return math.max(1, math.min(widthLimited, heightLimited));
  }

  Widget _buildGridItemTile({
    required LayoutEditItem item,
    required double cellSize,
  }) {
    final width = (item.width * cellSize) + ((item.width - 1) * widget.gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * widget.gridGap);
    final definition = widget.itemDefinitionsById[item.id];
    final previewStyle = definition?.previewStyle ?? RemoteLayoutPreviewStyle.standard;
    final icon = definition?.icon ?? item.icon;
    final label = definition?.label ?? item.label;
    final isPower = definition?.isPower ?? item.isPower;

    if (previewStyle == RemoteLayoutPreviewStyle.circularDpad) {
      return RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
            child: FittedBox(
            fit: BoxFit.contain,
            child: AbsorbPointer(
              child: RemoteCircularDpad(
                onUp: _noop,
                onDown: _noop,
                onLeft: _noop,
                onRight: _noop,
                onOk: _noop,
              ),
            ),
          ),
        ),
      );
    }
    if (previewStyle == RemoteLayoutPreviewStyle.verticalRocker) {
      return RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
            child: FittedBox(
            fit: BoxFit.fill,
            child: AbsorbPointer(
              child: RemoteVerticalRocker(
                topText: '+',
                centerText: label ?? '',
                bottomText: '-',
                onTopTap: _noop,
                onBottomTap: _noop,
              ),
            ),
          ),
        ),
      );
    }

    final appColors = AppTheme.colorsOf(context);
    final background = isPower ? Colors.red.shade600 : appColors.remoteSurface;

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: item.width == 1 && item.height == 1
              ? BoxShape.circle
              : BoxShape.rectangle,
          borderRadius: item.width == 1 && item.height == 1
              ? null
              : BorderRadius.circular(cellSize * 0.6),
          color: background,
          border: Border.all(color: appColors.remoteOutline, width: 1.2),
        ),
        child: switch (previewStyle) {
          RemoteLayoutPreviewStyle.playPause => Builder(
              builder: (_) {
                final glyphSize = math.min(width, height) * 0.24;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: glyphSize + 2,
                      ),
                      SizedBox(width: math.max(1, glyphSize * 0.08)),
                      Icon(Icons.pause, color: Colors.white, size: glyphSize + 1),
                    ],
                  ),
                );
              },
            ),
          RemoteLayoutPreviewStyle.centeredCircleIcon => Center(
              child: RemoteIconCircleButton(
                icon: icon,
                label: label,
                onPressed: null,
              ),
            ),
          RemoteLayoutPreviewStyle.standard => icon != null
              ? Icon(
                  icon,
                  size: math.min(width, height) * 0.45,
                  color: Colors.white,
                )
              : Center(
                  child: Text(
                    label ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
          // Unreachable: handled above before building the chrome [circularDpad] / [verticalRocker].
          RemoteLayoutPreviewStyle.circularDpad => const SizedBox.shrink(),
          RemoteLayoutPreviewStyle.verticalRocker => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _buildLayoutGridCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final cellSize = _fitCellSize(maxWidth: maxWidth, maxHeight: maxHeight);
        final gridWidth =
            (widget.gridColumns * cellSize) + ((widget.gridColumns - 1) * widget.gridGap);
        final gridHeight =
            (widget.gridRows * cellSize) + ((widget.gridRows - 1) * widget.gridGap);
        final occupancyByCell = _buildOccupancyByCell(widget.layoutItems);
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
                    painter: _EditGridPainter(
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
                          return _willAcceptDropAtCell(
                            movingId: details.data,
                            hoverCol: col,
                            hoverRow: row,
                            occupancyByCell: occupancyByCell,
                            itemsById: itemsById,
                          );
                        },
                        onMove: (details) {
                          final resolved = _resolveDrop(
                            movingId: details.data,
                            hoverCol: col,
                            hoverRow: row,
                            occupancyByCell: occupancyByCell,
                            itemsById: itemsById,
                          );
                          _updateActiveDragHover(
                            resolved: resolved,
                            movingId: details.data,
                            hoverCol: col,
                            hoverRow: row,
                            itemsById: itemsById,
                          );
                          _lastDragAttempt = _LastDragAttempt(
                            movingId: details.data,
                            hoverCol: col,
                            hoverRow: row,
                            canDrop: resolved != null,
                          );
                        },
                        onLeave: (_) {
                          final hover = _activeDragHover;
                          if (hover == null ||
                              hover.hoverCol != col ||
                              hover.hoverRow != row) {
                            return;
                          }
                          setState(() {
                            _activeDragHover = null;
                          });
                        },
                        onAcceptWithDetails: (details) {
                          final resolved = _resolveDrop(
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
                          });
                          _dragAcceptedInCurrentSession = true;
                          unawaited(widget.onPersistLayout());
                        },
                        builder: (context, candidateData, _) {
                          // Candidate list is non-empty only while a compatible drag is over this cell
                          // and [onWillAcceptWithDetails] allows a drop here.
                          final footprintHover = _cellInActiveFootprint(col, row);
                          final hoverCanDrop = _activeDragHover?.canDrop ?? false;
                          final directTarget = candidateData.isNotEmpty;
                          final highlightDrop = directTarget || footprintHover;
                          final borderColor = !highlightDrop
                              ? slotBorderColor
                              : (hoverCanDrop
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFF9800));
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
                      // While dragging, let grid DragTargets receive hit tests.
                      ignoring: _isDraggingLayoutItem,
                      child: Draggable<String>(
                        data: item.id,
                        onDragStarted: () {
                          if (_isDraggingLayoutItem) {
                            return;
                          }
                          setState(() {
                            _isDraggingLayoutItem = true;
                          });
                          _dragAcceptedInCurrentSession = false;
                          _lastDragAttempt = null;
                        },
                        onDragEnd: (_) {
                          if (!_dragAcceptedInCurrentSession) {
                            final attempt = _lastDragAttempt;
                            if (attempt != null && attempt.movingId == item.id) {
                            }
                          }
                          if (!mounted) {
                            return;
                          }
                          if (!_isDraggingLayoutItem) {
                            return;
                          }
                          setState(_clearDragTracking);
                        },
                        onDraggableCanceled: (velocity, offset) {
                          if (!_dragAcceptedInCurrentSession) {
                            final attempt = _lastDragAttempt;
                            if (attempt != null && attempt.movingId == item.id) {
                            }
                          }
                          if (!mounted) {
                            return;
                          }
                          setState(_clearDragTracking);
                        },
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(
                            opacity: 0.85,
                            child: _buildGridItemTile(item: item, cellSize: cellSize),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _buildGridItemTile(item: item, cellSize: cellSize),
                        ),
                        child: Listener(
                          onPointerDown: (event) {
                            _recordDragAnchor(
                              item: item,
                              localPosition: event.localPosition,
                              cellSize: cellSize,
                            );
                          },
                          child: _buildGridItemTile(item: item, cellSize: cellSize),
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

class _DragAnchorOffset {
  const _DragAnchorOffset({required this.colOffset, required this.rowOffset});

  final int colOffset;
  final int rowOffset;
}

class _ActiveDragHover {
  const _ActiveDragHover({
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
    return other is _ActiveDragHover &&
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

class _LastDragAttempt {
  const _LastDragAttempt({
    required this.movingId,
    required this.hoverCol,
    required this.hoverRow,
    required this.canDrop,
  });

  final String movingId;
  final int hoverCol;
  final int hoverRow;
  final bool canDrop;
}

/// Faint lines at cell boundaries so edit mode reads as an explicit grid.
class _EditGridPainter extends CustomPainter {
  _EditGridPainter({
    required this.columns,
    required this.rows,
    required this.cellSize,
    required this.gap,
    required this.lineColor,
  });

  final int columns;
  final int rows;
  final double cellSize;
  final double gap;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    for (var i = 0; i <= columns; i++) {
      final x = i == columns ? w : i * (cellSize + gap);
      canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
    }
    for (var j = 0; j <= rows; j++) {
      final y = j == rows ? h : j * (cellSize + gap);
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EditGridPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.gap != gap ||
        oldDelegate.lineColor != lineColor;
  }
}
