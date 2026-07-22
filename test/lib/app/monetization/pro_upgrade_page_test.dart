import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:one_remote/app/monetization/pro_upgrade_page.dart';
import 'package:one_remote/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'shows loading then empty state when no Pro plans are available',
    (tester) async {
      final completer = Completer<List<ProductDetails>>();

      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      unawaited(
        ProUpgradePage.show(
          context: tester.element(find.byType(Scaffold)),
          loadProducts: () => completer.future,
          onPurchase: (_) async => true,
          onRestorePurchases: () async {},
        ),
      );
      await tester.pump();

      expect(find.text('Loading prices…'), findsOneWidget);

      completer.complete(const <ProductDetails>[]);
      await tester.pumpAndSettle();

      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
    },
  );
}

class _Harness extends StatelessWidget {
  const _Harness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox.shrink()),
    );
  }
}
