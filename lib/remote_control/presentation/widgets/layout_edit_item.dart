import 'package:flutter/material.dart';

/// Mutable grid item used by remote layout rendering and editor interactions.
class LayoutEditItem {
  LayoutEditItem({
    required this.id,
    this.icon,
    this.label,
    required this.col,
    required this.row,
    this.width = 1,
    this.height = 1,
    this.isPower = false,
  });

  final String id;
  final IconData? icon;
  final String? label;
  int col;
  int row;
  final int width;
  final int height;
  final bool isPower;
}
