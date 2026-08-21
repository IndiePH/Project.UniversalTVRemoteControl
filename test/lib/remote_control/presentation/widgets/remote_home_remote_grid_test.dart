import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/domain/models/layout_zone.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_grid_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_home_remote_grid.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';

void main() {
  Widget buildGrid({required List<LayoutEditItem> layoutItems}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 700,
          child: RemoteHomeRemoteGrid(
            layoutItems: layoutItems,
            gridColumns: kRemoteLayoutGridColumns,
            gridRows: kRemoteLayoutGridRows,
            gridGap: kRemoteLayoutGridGap,
            controlsEnabled: true,
            pairingHintActive: false,
            onSendCommand: (RemoteCommand _) {},
            onSearchInputPressed: () {},
            onDisabledInteraction: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders a grid-zoned item', (tester) async {
    final items = buildInitialRemoteLayoutItems();
    await tester.pumpWidget(buildGrid(layoutItems: items));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets('does not render a drawer-zoned item', (tester) async {
    final items = buildInitialRemoteLayoutItems();
    items.firstWhere((item) => item.id == 'mute').zone = LayoutZone.drawer;

    await tester.pumpWidget(buildGrid(layoutItems: items));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byIcon(Icons.volume_off), findsNothing);
  });
}
