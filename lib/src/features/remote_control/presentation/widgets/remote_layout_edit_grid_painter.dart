import 'package:flutter/material.dart';

/// Faint lines at cell boundaries so edit mode reads as an explicit grid.
class RemoteLayoutEditGridPainter extends CustomPainter {
  RemoteLayoutEditGridPainter({
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
  bool shouldRepaint(covariant RemoteLayoutEditGridPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.gap != gap ||
        oldDelegate.lineColor != lineColor;
  }
}
