import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/domain/models/layout_zone.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_editor_metrics.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_grid_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor_item_preview.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';

ThemeData _layoutEditorTestTheme() {
  return ThemeData(
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: kRemoteLayoutEditorTitleFontSize),
      bodyMedium: TextStyle(fontSize: kRemoteLayoutEditorBodyFontSize),
    ),
  );
}

Widget _layoutEditorTestViewport({required Widget child}) {
  return SizedBox(
    width: kRemoteLayoutEditorTestViewportWidth,
    height: kRemoteLayoutEditorTestViewportHeight,
    child: child,
  );
}

void main() {
  Widget buildEditor({
    required List<LayoutEditItem> layoutItems,
    VoidCallback? onPersist,
  }) {
    return MaterialApp(
      theme: _layoutEditorTestTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: _layoutEditorTestViewport(
          child: RemoteLayoutEditor(
            layoutItems: layoutItems,
            itemDefinitionsById: kRemoteLayoutItemDefinitionById,
            gridColumns: kRemoteLayoutGridColumns,
            gridRows: kRemoteLayoutGridRows,
            gridGap: kRemoteLayoutGridGap,
            onResetLayout: () async {},
            onPersistLayout: () async {
              onPersist?.call();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('shows layout editor chrome', (tester) async {
    final items = buildInitialRemoteLayoutItems();
    await tester.pumpWidget(buildEditor(layoutItems: items));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('Layout Editor'), findsOneWidget);
    expect(find.byTooltip('Reset Layout'), findsOneWidget);
  });

  testWidgets('reset button invokes onResetLayout', (tester) async {
    var resetCalls = 0;
    final items = buildInitialRemoteLayoutItems();
    await tester.pumpWidget(
      MaterialApp(
        theme: _layoutEditorTestTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: _layoutEditorTestViewport(
            child: RemoteLayoutEditor(
              layoutItems: items,
              itemDefinitionsById: kRemoteLayoutItemDefinitionById,
              gridColumns: kRemoteLayoutGridColumns,
              gridRows: kRemoteLayoutGridRows,
              gridGap: kRemoteLayoutGridGap,
              onResetLayout: () async {
                resetCalls++;
              },
              onPersistLayout: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byTooltip('Reset Layout'));
    await tester.pumpAndSettle();

    expect(resetCalls, 1);
  });

  group('drawer', () {
    const emptyHint = 'Drag a button here to remove it from your remote.';

    testWidgets('shows the empty-state hint when nothing is parked', (
      tester,
    ) async {
      final items = buildInitialRemoteLayoutItems();
      await tester.pumpWidget(buildEditor(layoutItems: items));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text(emptyHint), findsOneWidget);
    });

    testWidgets('renders a drawer-zoned item and hides the empty-state hint', (
      tester,
    ) async {
      final items = buildInitialRemoteLayoutItems();
      items.firstWhere((item) => item.id == 'mute').zone = LayoutZone.drawer;

      await tester.pumpWidget(buildEditor(layoutItems: items));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text(emptyHint), findsNothing);
      // Every item still renders exactly one preview, grid or drawer.
      expect(
        find.byType(RemoteLayoutEditorItemPreview),
        findsNWidgets(items.length),
      );
    });

    testWidgets('dragging a grid item onto the drawer parks it and persists', (
      tester,
    ) async {
      final items = buildInitialRemoteLayoutItems();
      final mute = items.firstWhere((item) => item.id == 'mute');
      var persistCalls = 0;

      await tester.pumpWidget(
        buildEditor(layoutItems: items, onPersist: () => persistCalls++),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(mute.zone, LayoutZone.grid);

      final draggable = find.byWidgetPredicate(
        (widget) => widget is Draggable<String> && widget.data == 'mute',
      );
      // The drawer strip is the first DragTarget<String> built in the tree,
      // ahead of the grid's per-cell targets.
      final drawerTarget = find.byType(DragTarget<String>).first;

      final gesture = await tester.startGesture(tester.getCenter(draggable));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(drawerTarget));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();
      tester.takeException();

      expect(mute.zone, LayoutZone.drawer);
      final muteDefinition = kRemoteLayoutItemDefinitionById['mute']!;
      expect(mute.col, muteDefinition.col);
      expect(mute.row, muteDefinition.row);
      expect(persistCalls, 1);
    });

    testWidgets(
      'dragging a drawer item onto its last grid cell restores it and persists',
      (tester) async {
        final items = buildInitialRemoteLayoutItems();
        final muteDefinition = kRemoteLayoutItemDefinitionById['mute']!;
        final mute = items.firstWhere((item) => item.id == 'mute')
          ..zone = LayoutZone.drawer;
        var persistCalls = 0;

        await tester.pumpWidget(
          buildEditor(layoutItems: items, onPersist: () => persistCalls++),
        );
        await tester.pumpAndSettle();
        tester.takeException();

        final draggable = find.byWidgetPredicate(
          (widget) => widget is Draggable<String> && widget.data == 'mute',
        );
        // Grid DragTargets start at index 1 (index 0 is the drawer's own
        // target); row-major order matches the nested loop in
        // RemoteLayoutEditor. Targeting mute's own default cell keeps this
        // test correct even if the catalog's default positions change.
        final targetIndex =
            1 +
            (muteDefinition.row * kRemoteLayoutGridColumns +
                muteDefinition.col);
        final gridTarget = find.byType(DragTarget<String>).at(targetIndex);

        final gesture = await tester.startGesture(
          tester.getCenter(draggable),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(tester.getCenter(gridTarget));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();
        tester.takeException();

        expect(mute.zone, LayoutZone.grid);
        expect(mute.col, muteDefinition.col);
        expect(mute.row, muteDefinition.row);
        expect(persistCalls, 1);
      },
    );
  });
}
