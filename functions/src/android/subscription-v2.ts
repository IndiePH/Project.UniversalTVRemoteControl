import { androidpublisher_v3 } from 'googleapis';

const ACTIVE_SUBSCRIPTION_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

export function productIdFromSubscriptionV2(
  data: androidpublisher_v3.Schema$SubscriptionPurchaseV2,
): string | null {
  for (const item of data.lineItems ?? []) {
    const productId = item.productId?.trim();
    if (productId) {
      return productId;
    }
  }
  return null;
}

export function subscriptionEntitlementFromV2(
  data: androidpublisher_v3.Schema$SubscriptionPurchaseV2,
): { entitled: boolean; expiresAtEpochMs: number | null } {
  const state = data.subscriptionState ?? '';
  if (!ACTIVE_SUBSCRIPTION_STATES.has(state)) {
    return { entitled: false, expiresAtEpochMs: null };
  }

  let expiresAtEpochMs: number | null = null;
  for (const item of data.lineItems ?? []) {
    const expiryTime = item.expiryTime;
    if (!expiryTime) {
      continue;
    }
    const ms = Date.parse(expiryTime);
    if (Number.isFinite(ms)) {
      expiresAtEpochMs =
        expiresAtEpochMs == null ? ms : Math.max(expiresAtEpochMs, ms);
    }
  }

  if (expiresAtEpochMs != null && Date.now() >= expiresAtEpochMs) {
    return { entitled: false, expiresAtEpochMs };
  }

  return { entitled: true, expiresAtEpochMs };
}
