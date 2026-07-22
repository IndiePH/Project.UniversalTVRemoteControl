import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_editor_metrics.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_grid_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_editor.dart';
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
  Widget buildEditor({required List<LayoutEditItem> layoutItems}) {
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
            onPersistLayout: () async {},
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
}
