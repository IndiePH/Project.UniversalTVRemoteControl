/// Play Console product IDs for Pro purchases.
abstract final class ProProductIds {
  static const String lifetime = 'lifetime';

  static const String subWeekly = 'sub_weekly';
  static const String subMonthly = 'sub_monthly';
  static const String subAnnually = 'sub_annually';

  /// All Pro products in display order (subscriptions first, then lifetime).
  static const List<String> catalog = <String>[
    subWeekly,
    subMonthly,
    subAnnually,
    lifetime,
  ];
}
