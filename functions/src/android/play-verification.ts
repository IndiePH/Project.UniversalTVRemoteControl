import { logger } from 'firebase-functions';
import { PRO_SUBSCRIPTION_PRODUCT_IDS } from '../pro/catalog.js';
import { getAndroidPublisherClient } from './publisher-client.js';
import {
  productIdFromSubscriptionV2,
  subscriptionEntitlementFromV2,
} from './subscription-v2.js';

async function verifyAndroidProductPurchase(params: {
  packageName: string;
  productId: string;
  purchaseToken: string;
}): Promise<{ entitled: boolean }> {
  const androidpublisher = getAndroidPublisherClient();

  const res = await androidpublisher.purchases.products.get({
    packageName: params.packageName,
    productId: params.productId,
    token: params.purchaseToken,
  });

  // Play returns a 200 response for valid tokens; the purchaseState indicates
  // whether it was purchased.
  //
  // purchaseState: 0 Purchased, 1 Canceled, 2 Pending (docs)
  const purchaseState = res.data.purchaseState;
  const entitled = purchaseState === 0;
  return { entitled };
}

async function verifyAndroidSubscriptionPurchase(params: {
  packageName: string;
  hintProductId: string;
  purchaseToken: string;
}): Promise<{
  entitled: boolean;
  expiresAtEpochMs: number | null;
  resolvedProductId: string;
}> {
  const androidpublisher = getAndroidPublisherClient();

  // Play Billing v5+ subscriptions require the subscriptionsv2 API (token only).
  try {
    const v2 = await androidpublisher.purchases.subscriptionsv2.get({
      packageName: params.packageName,
      token: params.purchaseToken,
    });
    const entitlement = subscriptionEntitlementFromV2(v2.data);
    const resolvedProductId =
      productIdFromSubscriptionV2(v2.data) ?? params.hintProductId;
    return { ...entitlement, resolvedProductId };
  } catch (v2Error) {
    logger.warn('subscriptionsv2.get failed; falling back to subscriptions.get', {
      hintProductId: params.hintProductId,
      error: v2Error instanceof Error ? v2Error.message : String(v2Error),
    });
  }

  const candidates = [
    params.hintProductId,
    ...PRO_SUBSCRIPTION_PRODUCT_IDS,
  ].filter((id, index, all) => all.indexOf(id) === index);

  for (const subscriptionId of candidates) {
    try {
      const res = await androidpublisher.purchases.subscriptions.get({
        packageName: params.packageName,
        subscriptionId,
        token: params.purchaseToken,
      });

      const expiryTimeMillis = res.data.expiryTimeMillis;
      const expiresAtEpochMs =
        typeof expiryTimeMillis === 'string' ? Number(expiryTimeMillis) : null;

      const entitled =
        expiresAtEpochMs != null && Number.isFinite(expiresAtEpochMs)
          ? Date.now() < expiresAtEpochMs
          : false;

      if (entitled) {
        return {
          entitled: true,
          expiresAtEpochMs,
          resolvedProductId: subscriptionId,
        };
      }
    } catch (fallbackError) {
      logger.debug('subscriptions.get failed for candidate product', {
        subscriptionId,
        error:
          fallbackError instanceof Error
            ? fallbackError.message
            : String(fallbackError),
      });
    }
  }

  return {
    entitled: false,
    expiresAtEpochMs: null,
    resolvedProductId: params.hintProductId,
  };
}

export type PlayVerificationResult = {
  entitled: boolean;
  expiresAtEpochMs: number | null;
  resolvedProductId: string;
};

export async function verifyProAndroidPlayPurchase(params: {
  packageName: string;
  productId: string;
  purchaseToken: string;
  kind: 'lifetime' | 'subscription';
}): Promise<PlayVerificationResult> {
  if (params.kind === 'subscription') {
    return verifyAndroidSubscriptionPurchase({
      packageName: params.packageName,
      hintProductId: params.productId,
      purchaseToken: params.purchaseToken,
    });
  }

  const { entitled } = await verifyAndroidProductPurchase({
    packageName: params.packageName,
    productId: params.productId,
    purchaseToken: params.purchaseToken,
  });
  return {
    entitled,
    expiresAtEpochMs: null,
    resolvedProductId: params.productId,
  };
}
