import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_grid_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor_grid_geometry.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';

bool _footprintsOverlap({
  required LayoutEditItem a,
  required LayoutEditItem b,
}) {
  final footprintA = RemoteLayoutEditorGridGeometry.validationFootprintFor(a);
  final footprintB = RemoteLayoutEditorGridGeometry.validationFootprintFor(b);
  return a.col < b.col + footprintB.width &&
      a.col + footprintA.width > b.col &&
      a.row < b.row + footprintB.height &&
      a.row + footprintA.height > b.row;
}

bool _fitsGrid(LayoutEditItem item) {
  final footprint = RemoteLayoutEditorGridGeometry.validationFootprintFor(item);
  return item.col >= 0 &&
      item.row >= 0 &&
      item.col + footprint.width <= kRemoteLayoutGridColumns &&
      item.row + footprint.height <= kRemoteLayoutGridRows;
}

void main() {
  group('default remote layout (5x9)', () {
    test('initial layout items fit inside grid using validation footprints', () {
      final items = buildInitialRemoteLayoutItems();
      for (final item in items) {
        expect(
          _fitsGrid(item),
          isTrue,
          reason:
              '${item.id} footprint exceeds ${kRemoteLayoutGridColumns}x${kRemoteLayoutGridRows}',
        );
      }
    });

    test('initial layout has no overlapping validation footprints', () {
      final items = buildInitialRemoteLayoutItems();
      for (var i = 0; i < items.length; i++) {
        for (var j = i + 1; j < items.length; j++) {
          expect(
            _footprintsOverlap(a: items[i], b: items[j]),
            isFalse,
            reason: '${items[i].id} overlaps ${items[j].id}',
          );
        }
      }
    });

    test('occupancy map assigns one owner per cell', () {
      final items = buildInitialRemoteLayoutItems();
      final occupancy = RemoteLayoutEditorGridGeometry.occupancyByCell(items);
      final ownersByCell = <String, String>{};
      for (final entry in occupancy.entries) {
        final prior = ownersByCell[entry.key];
        expect(prior, isNull, reason: 'duplicate cell ${entry.key}');
        ownersByCell[entry.key] = entry.value;
      }
    });
  });
}
