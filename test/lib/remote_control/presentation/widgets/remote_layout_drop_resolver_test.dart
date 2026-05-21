import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_grid_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_drop_resolver.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor_grid_geometry.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';

final _dpadDefinition = kRemoteLayoutItemDefinitionById['dpad']!;
final _homeDefinition = kRemoteLayoutItemDefinitionById['home']!;
final _menuDefinition = kRemoteLayoutItemDefinitionById['menu']!;
final _lastGridCol = kRemoteLayoutGridColumns - 1;
final _lastGridRow = kRemoteLayoutGridRows - 1;

LayoutEditItem _item({
  required String id,
  required int col,
  required int row,
  int width = 1,
  int height = 1,
}) {
  return LayoutEditItem(
    id: id,
    col: col,
    row: row,
    width: width,
    height: height,
  );
}

Map<String, LayoutEditItem> _itemsById(List<LayoutEditItem> items) {
  return {for (final item in items) item.id: item};
}

void main() {
  late RemoteLayoutDropResolver resolver;

  setUp(() {
    resolver = RemoteLayoutDropResolver(
      RemoteLayoutEditorGridGeometry.validationFootprintFor,
    );
  });

  group('resolveDrop', () {
    test('accepts move onto empty cells', () {
      final items = [
        _item(id: 'a', col: 0, row: 0),
        _item(id: 'b', col: _lastGridCol, row: _lastGridRow),
      ];
      final occupancy = RemoteLayoutEditorGridGeometry.occupancyByCell(items);

      final resolved = resolver.resolveDrop(
        gridColumns: kRemoteLayoutGridColumns,
        gridRows: kRemoteLayoutGridRows,
        movingId: 'a',
        hoverCol: 2,
        hoverRow: 8,
        occupancyByCell: occupancy,
        itemsById: _itemsById(items),
        anchorColOffset: 0,
        anchorRowOffset: 0,
      );

      expect(resolved, isNotNull);
      expect(resolved!.displacedPlacement, isNull);
      expect(resolved.movingPlacement.col, 2);
      expect(resolved.movingPlacement.row, _lastGridRow);
    });

    test('rejects drop when moving footprint exceeds grid bounds', () {
      final items = [
        _item(
          id: 'dpad',
          col: _dpadDefinition.col,
          row: _dpadDefinition.row,
          width: _dpadDefinition.width,
          height: _dpadDefinition.height,
        ),
      ];
      final occupancy = RemoteLayoutEditorGridGeometry.occupancyByCell(items);

      final resolved = resolver.resolveDrop(
        gridColumns: kRemoteLayoutGridColumns,
        gridRows: kRemoteLayoutGridRows,
        movingId: 'dpad',
        hoverCol: 3,
        hoverRow: 7,
        occupancyByCell: occupancy,
        itemsById: _itemsById(items),
        anchorColOffset: 0,
        anchorRowOffset: 0,
      );

      expect(resolved, isNull);
    });

    test('accepts adjacent 1x1 swap when dropping onto a single occupant', () {
      final items = [
        _item(id: 'left', col: 0, row: 0),
        _item(id: 'right', col: 1, row: 0),
      ];
      final occupancy = RemoteLayoutEditorGridGeometry.occupancyByCell(items);

      final resolved = resolver.resolveDrop(
        gridColumns: kRemoteLayoutGridColumns,
        gridRows: kRemoteLayoutGridRows,
        movingId: 'left',
        hoverCol: 1,
        hoverRow: 0,
        occupancyByCell: occupancy,
        itemsById: _itemsById(items),
        anchorColOffset: 0,
        anchorRowOffset: 0,
      );

      expect(resolved, isNotNull);
      expect(resolved!.displacedPlacement?.item.id, 'right');
    });

    test('accepts swap between two 1x1 controls', () {
      final items = [
        _item(
          id: 'home',
          col: _homeDefinition.col,
          row: _homeDefinition.row,
        ),
        _item(
          id: 'menu',
          col: _menuDefinition.col,
          row: _menuDefinition.row,
        ),
      ];
      final occupancy = RemoteLayoutEditorGridGeometry.occupancyByCell(items);

      final resolved = resolver.resolveDrop(
        gridColumns: kRemoteLayoutGridColumns,
        gridRows: kRemoteLayoutGridRows,
        movingId: 'menu',
        hoverCol: 2,
        hoverRow: 0,
        occupancyByCell: occupancy,
        itemsById: _itemsById(items),
        anchorColOffset: 0,
        anchorRowOffset: 0,
      );

      expect(resolved, isNotNull);
      expect(resolved!.movingPlacement.item.id, 'menu');
      expect(resolved.movingPlacement.col, _homeDefinition.col);
      expect(resolved.movingPlacement.row, _homeDefinition.row);
      expect(resolved.displacedPlacement?.item.id, 'home');
      expect(resolved.displacedPlacement?.col, _menuDefinition.col);
      expect(resolved.displacedPlacement?.row, _menuDefinition.row);
    });

    test('rejects drop when validation footprint spans multiple controls', () {
      final items = [
        _item(id: 'blockerA', col: 0, row: 0),
        _item(id: 'blockerB', col: 1, row: 0),
        _item(id: 'moving', col: 3, row: 0, width: 2, height: 1),
      ];
      final occupancy = RemoteLayoutEditorGridGeometry.occupancyByCell(items);

      final resolved = resolver.resolveDrop(
        gridColumns: kRemoteLayoutGridColumns,
        gridRows: kRemoteLayoutGridRows,
        movingId: 'moving',
        hoverCol: 0,
        hoverRow: 0,
        occupancyByCell: occupancy,
        itemsById: _itemsById(items),
        anchorColOffset: 0,
        anchorRowOffset: 0,
      );

      expect(resolved, isNull);
    });

    test('rejects swap when displaced dpad has no non-overlapping placement', () {
      bool isDpadCell(int col, int row) =>
          col >= _dpadDefinition.col &&
          col < _dpadDefinition.col + _dpadDefinition.width &&
          row >= _dpadDefinition.row &&
          row < _dpadDefinition.row + _dpadDefinition.height;
      final items = <LayoutEditItem>[
        for (var col = 0; col < kRemoteLayoutGridColumns; col++)
          for (var row = 0; row < kRemoteLayoutGridRows; row++)
            if (!isDpadCell(col, row))
              _item(id: 'fill-$col-$row', col: col, row: row),
        _item(
          id: 'dpad',
          col: _dpadDefinition.col,
          row: _dpadDefinition.row,
          width: _dpadDefinition.width,
          height: _dpadDefinition.height,
        ),
        _item(id: 'menu', col: _lastGridCol, row: _lastGridRow),
      ];
      final occupancy = RemoteLayoutEditorGridGeometry.occupancyByCell(items);

      final resolved = resolver.resolveDrop(
        gridColumns: kRemoteLayoutGridColumns,
        gridRows: kRemoteLayoutGridRows,
        movingId: 'menu',
        hoverCol: 2,
        hoverRow: 3,
        occupancyByCell: occupancy,
        itemsById: _itemsById(items),
        anchorColOffset: 0,
        anchorRowOffset: 0,
      );

      expect(resolved, isNull);
    });

    test('respects drag anchor offsets when resolving hover cell', () {
      final items = [
        _item(id: 'wide', col: 0, row: 0, width: 2, height: 1),
      ];
      final occupancy = RemoteLayoutEditorGridGeometry.occupancyByCell(items);

      final resolved = resolver.resolveDrop(
        gridColumns: kRemoteLayoutGridColumns,
        gridRows: kRemoteLayoutGridRows,
        movingId: 'wide',
        hoverCol: 3,
        hoverRow: 0,
        occupancyByCell: occupancy,
        itemsById: _itemsById(items),
        anchorColOffset: 1,
        anchorRowOffset: 0,
      );

      expect(resolved, isNotNull);
      expect(resolved!.movingPlacement.col, 2);
      expect(resolved.movingPlacement.row, 0);
    });
  });
}
