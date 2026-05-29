import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:one_remote/app/monetization/pro_product_ids.dart';
import 'package:one_remote/l10n/app_localizations.dart';

typedef ProProductLoader = Future<List<ProductDetails>> Function();
typedef ProProductPurchaseStarter =
    Future<bool> Function(ProductDetails product);

const double _contentPadding = 8;
const double _maxDialogHeightFraction = 0.55;

int _proPlanSortKey(ProductDetails product) {
  final productIndex = ProProductIds.catalog.indexOf(product.id);
  final group =
      productIndex >= 0 ? productIndex : ProProductIds.catalog.length;
  final offerIndex = _proPlanOfferSortKey(product);
  return group * 10 + offerIndex;
}

int _proPlanOfferSortKey(ProductDetails product) {
  if (product is GooglePlayProductDetails &&
      product.subscriptionIndex != null) {
    final offers = product.productDetails.subscriptionOfferDetails;
    if (offers != null && product.subscriptionIndex! < offers.length) {
      final basePlanId = offers[product.subscriptionIndex!].basePlanId;
      if (basePlanId.contains('prepaid')) {
        return 1;
      }
    }
  }
  return 0;
}

List<ProductDetails> _sortedProPlans(List<ProductDetails> products) {
  final plans = List<ProductDetails>.from(products);
  plans.sort((a, b) => _proPlanSortKey(a).compareTo(_proPlanSortKey(b)));
  return plans;
}

String _proPlanTitle(AppLocalizations l10n, ProductDetails product) {
  if (product is GooglePlayProductDetails &&
      product.subscriptionIndex != null) {
    final offers = product.productDetails.subscriptionOfferDetails;
    if (offers != null && product.subscriptionIndex! < offers.length) {
      return switch (offers[product.subscriptionIndex!].basePlanId) {
        'sub-monthly-autorenew' => l10n.proPlanMonthlyAutoRenew,
        'sub-monthly-prepaid' => l10n.proPlanMonthlyPrepaid,
        'sub-weekly-autorenew' => l10n.proPlanWeeklyAutoRenew,
        'sub-weekly-prepaid' => l10n.proPlanWeeklyPrepaid,
        'sub-annually-autorenew' => l10n.proPlanAnnualAutoRenew,
        'sub-annually-prepaid' => l10n.proPlanAnnualPrepaid,
        _ => product.title,
      };
    }
  }
  return switch (product.id) {
    ProProductIds.subWeekly => l10n.proPlanWeeklyAutoRenew,
    ProProductIds.subMonthly => l10n.proPlanMonthlyAutoRenew,
    ProProductIds.subAnnually => l10n.proPlanAnnualAutoRenew,
    ProProductIds.lifetime => l10n.proPlanLifetime,
    _ => product.title,
  };
}

final class ProUpgradePage extends StatefulWidget {
  const ProUpgradePage({
    super.key,
    required this.loadProducts,
    required this.onPurchase,
    required this.onRestorePurchases,
    this.showRestorePurchases = true,
  });

  final ProProductLoader loadProducts;
  final ProProductPurchaseStarter onPurchase;
  final Future<void> Function() onRestorePurchases;
  final bool showRestorePurchases;

  static Future<bool?> show({
    required BuildContext context,
    required ProProductLoader loadProducts,
    required ProProductPurchaseStarter onPurchase,
    required Future<void> Function() onRestorePurchases,
    bool showRestorePurchases = true,
    bool useRootNavigator = true,
  }) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: useRootNavigator,
      builder: (dialogContext) => ProUpgradePage(
        loadProducts: loadProducts,
        onPurchase: onPurchase,
        onRestorePurchases: onRestorePurchases,
        showRestorePurchases: showRestorePurchases,
      ),
    );
  }

  @override
  State<ProUpgradePage> createState() => _ProUpgradePageState();
}

final class _ProUpgradePageState extends State<ProUpgradePage> {
  late Future<List<ProductDetails>> _productsFuture;
  String? _purchasingProductId;

  @override
  void initState() {
    super.initState();
    _productsFuture = widget.loadProducts();
  }

  Future<void> _startPurchase(ProductDetails product) async {
    setState(() => _purchasingProductId = product.id);
    final started = await widget.onPurchase(product);
    if (!mounted) {
      return;
    }
    setState(() => _purchasingProductId = null);
    if (started) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _restorePurchases() async {
    await widget.onRestorePurchases();
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight =
        MediaQuery.sizeOf(context).height * _maxDialogHeightFraction;

    return AlertDialog(
      title: Text(l10n.proChoosePlanPrompt),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: FutureBuilder<List<ProductDetails>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              final plans = snapshot.hasData
                  ? _sortedProPlans(snapshot.data!)
                  : const <ProductDetails>[];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              if (isLoading) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: _contentPadding),
                  child: Text(
                    l10n.proPricesLoading,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: _contentPadding),
                  child: Text(
                    l10n.proStoreUnavailable,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              if (plans.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: _contentPadding),
                  child: Text(
                    l10n.proPlanUnavailable,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: plans.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_proPlanTitle(l10n, plan)),
                    trailing: _purchasingProductId == plan.id
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            plan.price,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                    enabled: _purchasingProductId == null,
                    onTap: () => _startPurchase(plan),
                  );
                },
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.uiCancel),
        ),
        if (widget.showRestorePurchases)
          FilledButton(
            onPressed: _restorePurchases,
            child: Text(l10n.proRestoreButton),
          ),
      ],
    );
  }
}
