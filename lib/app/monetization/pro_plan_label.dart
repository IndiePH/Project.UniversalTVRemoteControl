import 'package:one_remote/app/monetization/pro_product_ids.dart';
import 'package:one_remote/l10n/app_localizations.dart';

/// User-facing plan label for a Play product ID.
String proPlanLabelForProductId(AppLocalizations l10n, String productId) {
  return switch (productId) {
    ProProductIds.subWeekly => l10n.proPlanWeeklyAutoRenew,
    ProProductIds.subMonthly => l10n.proPlanMonthlyAutoRenew,
    ProProductIds.subAnnually => l10n.proPlanAnnualAutoRenew,
    ProProductIds.lifetime => l10n.proPlanLifetime,
    _ => productId,
  };
}
