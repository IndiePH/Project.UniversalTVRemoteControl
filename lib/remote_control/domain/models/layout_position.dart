import 'package:one_remote/remote_control/domain/models/layout_zone.dart';

/// Grid coordinates for a remote control item.
final class LayoutPosition {
  const LayoutPosition({
    required this.col,
    required this.row,
    this.zone = LayoutZone.grid,
  });

  final int col;
  final int row;
  final LayoutZone zone;

  Map<String, dynamic> toJson() => {'col': col, 'row': row, 'zone': zone.name};

  static LayoutPosition? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final col = json['col'];
    final row = json['row'];
    if (col is! int || row is! int) {
      return null;
    }
    final zone = LayoutZone.values.firstWhere(
      (value) => value.name == json['zone'],
      orElse: () => LayoutZone.grid,
    );
    return LayoutPosition(col: col, row: row, zone: zone);
  }
}
