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

    // Draw both edges of each cell so the painted cells match the actual
    // slot positions (each slot box is cellSize wide with gap between).
    for (var col = 0; col < columns; col++) {
      final leftX = col * (cellSize + gap);
      final rightX = leftX + cellSize;
      canvas.drawLine(Offset(leftX, 0), Offset(leftX, h), paint);
      canvas.drawLine(Offset(rightX, 0), Offset(rightX, h), paint);
    }
    for (var row = 0; row < rows; row++) {
      final topY = row * (cellSize + gap);
      final bottomY = topY + cellSize;
      canvas.drawLine(Offset(0, topY), Offset(w, topY), paint);
      canvas.drawLine(Offset(0, bottomY), Offset(w, bottomY), paint);
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
