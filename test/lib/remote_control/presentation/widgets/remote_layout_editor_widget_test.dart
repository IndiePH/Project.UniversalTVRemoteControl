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

  testWidgets('no overflow on a narrow screen with realistic app chrome', (
    tester,
  ) async {
    // The default 400px test viewport is more generous than a real small phone and missed a
    // RenderFlex overflow real-device testing found. Mirrors RemoteHomePage's actual chrome.
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final items = buildInitialRemoteLayoutItems();
    await tester.pumpWidget(
      MaterialApp(
        theme: _layoutEditorTestTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(toolbarHeight: 50, title: const Text('OneRemote')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RemoteLayoutEditor(
                layoutItems: items,
                itemDefinitionsById: kRemoteLayoutItemDefinitionById,
                gridColumns: kRemoteLayoutGridColumns,
                gridRows: kRemoteLayoutGridRows,
                gridGap: kRemoteLayoutGridGap,
                onResetLayout: () async {},
                onPersistLayout: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
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
        // Index 0 is the drawer's own target; grid targets follow in row-major order.
        final targetIndex =
            1 +
            (muteDefinition.row * kRemoteLayoutGridColumns +
                muteDefinition.col);
        final gridTarget = find.byType(DragTarget<String>).at(targetIndex);

        final gesture = await tester.startGesture(tester.getCenter(draggable));
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

    testWidgets('drawer box width matches grid width when there is room', (
      tester,
    ) async {
      // Wide enough that the grid's cell size is height-limited (fixed
      // regardless of width), leaving slack around it for the chevrons to
      // sit in without shrinking the box below grid width.
      final items = buildInitialRemoteLayoutItems();
      await tester.pumpWidget(
        MaterialApp(
          theme: _layoutEditorTestTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 520,
              height: kRemoteLayoutEditorTestViewportHeight,
              child: RemoteLayoutEditor(
                layoutItems: items,
                itemDefinitionsById: kRemoteLayoutItemDefinitionById,
                gridColumns: kRemoteLayoutGridColumns,
                gridRows: kRemoteLayoutGridRows,
                gridGap: kRemoteLayoutGridGap,
                onResetLayout: () async {},
                onPersistLayout: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      final gridPaintFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() ==
                'RemoteLayoutEditGridPainter',
      );
      final gridWidth = tester.getSize(gridPaintFinder).width;

      final drawerBoxWidth = tester
          .getSize(find.byKey(const ValueKey('drawerBox')))
          .width;

      expect(drawerBoxWidth, closeTo(gridWidth, 1.0));
    });

    testWidgets('drawer box shrinks below grid width on narrow screens', (
      tester,
    ) async {
      // At this width the chevron budget doesn't fit outside a box the
      // full grid width, so the box must shrink to keep both chevrons
      // on-screen and tappable rather than overflowing past the edge.
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = buildInitialRemoteLayoutItems();
      await tester.pumpWidget(
        MaterialApp(
          theme: _layoutEditorTestTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(toolbarHeight: 50, title: const Text('OneRemote')),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RemoteLayoutEditor(
                  layoutItems: items,
                  itemDefinitionsById: kRemoteLayoutItemDefinitionById,
                  gridColumns: kRemoteLayoutGridColumns,
                  gridRows: kRemoteLayoutGridRows,
                  gridGap: kRemoteLayoutGridGap,
                  onResetLayout: () async {},
                  onPersistLayout: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final gridPaintFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() ==
                'RemoteLayoutEditGridPainter',
      );
      final gridWidth = tester.getSize(gridPaintFinder).width;
      final drawerBoxWidth = tester
          .getSize(find.byKey(const ValueKey('drawerBox')))
          .width;

      expect(drawerBoxWidth, lessThan(gridWidth));
    });

    testWidgets('drawer hides chevrons instead of overflowing when there is no room for them', (
      tester,
    ) async {
      // Below the chevron budget (2 * (chevron size + gap)), reserving space for both chevrons
      // would overflow the row; the drawer should drop them and let the box take the full width.
      tester.view.physicalSize = const Size(100, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = buildInitialRemoteLayoutItems();
      await tester.pumpWidget(
        MaterialApp(
          theme: _layoutEditorTestTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(toolbarHeight: 50, title: const Text('OneRemote')),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RemoteLayoutEditor(
                  layoutItems: items,
                  itemDefinitionsById: kRemoteLayoutItemDefinitionById,
                  gridColumns: kRemoteLayoutGridColumns,
                  gridRows: kRemoteLayoutGridRows,
                  gridGap: kRemoteLayoutGridGap,
                  onResetLayout: () async {},
                  onPersistLayout: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byIcon(Icons.arrow_left), findsNothing);
      expect(find.byIcon(Icons.arrow_right), findsNothing);
      expect(find.byKey(const ValueKey('drawerBox')), findsOneWidget);
    });

    testWidgets('tapping the right triangle scrolls by one item', (
      tester,
    ) async {
      final items = buildInitialRemoteLayoutItems();
      for (final id in ['mute', 'netflix', 'disney', 'prime', 'back']) {
        items.firstWhere((item) => item.id == id).zone = LayoutZone.drawer;
      }
      await tester.pumpWidget(buildEditor(layoutItems: items));
      await tester.pumpAndSettle();
      tester.takeException();

      final scrollable = find.byType(Scrollable);
      final beforePixels = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;

      await tester.tap(find.byIcon(Icons.arrow_right));
      await tester.pumpAndSettle();
      tester.takeException();

      final afterPixels = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      expect(
        afterPixels - beforePixels,
        closeTo(kRemoteLayoutDrawerItemCellSize + kRemoteLayoutGridGap, 0.5),
      );
    });

    testWidgets('holding the right triangle scrolls continuously', (
      tester,
    ) async {
      final items = buildInitialRemoteLayoutItems();
      for (final id in ['mute', 'netflix', 'disney', 'prime', 'back']) {
        items.firstWhere((item) => item.id == id).zone = LayoutZone.drawer;
      }
      await tester.pumpWidget(buildEditor(layoutItems: items));
      await tester.pumpAndSettle();
      tester.takeException();

      final scrollable = find.byType(Scrollable);
      final beforePixels = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.arrow_right)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(kRemoteLayoutDrawerAutoScrollTickInterval * 10);
      await gesture.up();
      await tester.pumpAndSettle();
      tester.takeException();

      final afterPixels = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      // Holding scrolls further than a single tap would.
      expect(
        afterPixels - beforePixels,
        greaterThan(kRemoteLayoutDrawerItemCellSize + kRemoteLayoutGridGap),
      );
    });
  });
}
