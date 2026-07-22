const PRO_CATALOG = [
  'sub_weekly',
  'sub_monthly',
  'sub_annually',
  'lifetime',
] as const;

export const PRO_PRODUCT_IDS = new Set<string>(PRO_CATALOG);

export const PRO_SUBSCRIPTION_PRODUCT_IDS = PRO_CATALOG.filter((id) =>
  /^sub[-_]/.test(id),
);
