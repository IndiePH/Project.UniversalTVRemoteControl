// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remove_control/src/app/remote_one_app.dart';

void main() {
  testWidgets('renders remote home page shell', (WidgetTester tester) async {
    await tester.pumpWidget(const RemoteOneApp());
    await tester.pump();

    expect(find.text('RemoteOne'), findsOneWidget);
    expect(find.text('Living Room TV'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('WWW'), findsOneWidget);
    expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.byIcon(Icons.search), findsAtLeastNWidgets(1));
    expect(find.text('CH'), findsOneWidget);
    expect(find.text('VOL'), findsOneWidget);
  });
}
