import 'dart:math' as math;

import 'package:one_remote/remote_control/domain/models/layout_item_id.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_drop_resolver.dart';

/// Pure grid sizing and occupancy helpers for [RemoteLayoutEditor].
abstract final class RemoteLayoutEditorGridGeometry {
  /// Same rules as the drop resolver: dpad/channel/volume overrides, else item dimensions.
  static RemoteLayoutItemFootprint validationFootprintFor(LayoutEditItem item) {
    if (item.id == LayoutItemId.dpad) {
      return const RemoteLayoutItemFootprint(width: 3, height: 3);
    }
    if (item.id == LayoutItemId.volume || item.id == LayoutItemId.channel) {
      return const RemoteLayoutItemFootprint(width: 1, height: 3);
    }
    return RemoteLayoutItemFootprint(width: item.width, height: item.height);
  }

  static String cellKey(int col, int row) => '$col:$row';

  static Map<String, String> occupancyByCell(List<LayoutEditItem> items) {
    final map = <String, String>{};
    for (final item in items) {
      for (var row = item.row; row < item.row + item.height; row++) {
        for (var col = item.col; col < item.col + item.width; col++) {
          map[cellKey(col, row)] = item.id;
        }
      }
    }
    return map;
  }

  static double fitCellSize({
    required int gridColumns,
    required int gridRows,
    required double gridGap,
    required double maxWidth,
    required double maxHeight,
  }) {
    final widthLimited =
        (maxWidth - ((gridColumns - 1) * gridGap)) / gridColumns;
    final heightLimited = (maxHeight - ((gridRows - 1) * gridGap)) / gridRows;
    return math.max(1, math.min(widthLimited, heightLimited));
  }
}
