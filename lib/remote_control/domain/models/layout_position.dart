import 'package:one_remote/remote_control/domain/models/layout_category.dart';

/// Grid coordinates for a remote control item.
final class LayoutPosition {
  const LayoutPosition({
    required this.col,
    required this.row,
    this.category = LayoutCategory.grid,
  });

  final int col;
  final int row;
  final LayoutCategory category;

  Map<String, dynamic> toJson() => {
    'col': col,
    'row': row,
    'category': category.name,
  };

  static LayoutPosition? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final col = json['col'];
    final row = json['row'];
    if (col is! int || row is! int) {
      return null;
    }
    final category = LayoutCategory.values.firstWhere(
      (value) => value.name == json['category'],
      orElse: () => LayoutCategory.grid,
    );
    return LayoutPosition(col: col, row: row, category: category);
  }
}
