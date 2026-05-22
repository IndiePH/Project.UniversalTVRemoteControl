/// Grid coordinates for a remote control item.
final class LayoutPosition {
  const LayoutPosition({required this.col, required this.row});

  final int col;
  final int row;

  Map<String, dynamic> toJson() => {'col': col, 'row': row};

  static LayoutPosition? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final col = json['col'];
    final row = json['row'];
    if (col is! int || row is! int) {
      return null;
    }
    return LayoutPosition(col: col, row: row);
  }
}
