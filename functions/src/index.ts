import * as admin from 'firebase-admin';
import { createHash } from 'node:crypto';
import { logger } from 'firebase-functions';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { google, androidpublisher_v3 } from 'googleapis';

admin.initializeApp();

const PRO_CATALOG = [
  'sub_weekly',
  'sub_monthly',
  'sub_annually',
  'lifetime',
] as const;

const PRO_PRODUCT_IDS = new Set<string>(PRO_CATALOG);

const PRO_SUBSCRIPTION_PRODUCT_IDS = PRO_CATALOG.filter((id) =>
  /^sub[-_]/.test(id),
);

type VerifyProAndroidPurchaseRequest = {
  productId: string;
  purchaseToken: string;
};

type VerifyProAndroidPurchaseResponse = {
  entitled: boolean;
  productId: string;
  packageName: string;
  validatedAtEpochMs: number;
  expiresAtEpochMs: number | null;
  kind: 'lifetime' | 'subscription';
};

function requireString(
  value: unknown,
  name: string,
  maxLen: number,
): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', `${name} must be a string`);
  }
  const trimmed = value.trim();
  if (!trimmed) {
    throw new HttpsError('invalid-argument', `${name} is required`);
  }
  if (trimmed.length > maxLen) {
    throw new HttpsError('invalid-argument', `${name} is too long`);
  }
  return trimmed;
}

function requireAuthedUid(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  return uid;
}

function env(name: string): string {
  const v = process.env[name];
  if (!v || !v.trim()) {
    throw new HttpsError(
      'failed-precondition',
      `Missing required env var: ${name}`,
    );
  }
  return v.trim();
}

export function sha256Hex(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

export function proProductKindFor(
  productId: string,
): 'lifetime' | 'subscription' {
  return /^sub[-_]/.test(productId) ? 'subscription' : 'lifetime';
}

export function assertProProductIdAllowed(productId: string): void {
  if (!PRO_PRODUCT_IDS.has(productId)) {
    throw new HttpsError(
      'invalid-argument',
      `Unsupported Pro product ID: ${productId}`,
    );
  }
}

export function assertTokenOwner(
  existingUid: string | undefined,
  uid: string,
  entitled: boolean,
): void {
  if (existingUid != null && existingUid !== uid && !entitled) {
    // Do not throw: after reinstall the Firebase anonymous UID changes while
    // the Play token may still point at the old UID. Returning entitled:false
    // lets restore finish; the next successful validation can rebind.
    logger.warn('Purchase token linked to another uid and not entitled', {
      existingUid,
      uid,
    });
  }
}

let androidPublisherClient: androidpublisher_v3.Androidpublisher | null = null;

function getAndroidPublisherClient(): androidpublisher_v3.Androidpublisher {
  if (androidPublisherClient == null) {
    // Reuse one client per function instance; GoogleAuth caches ADC tokens.
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    androidPublisherClient = google.androidpublisher({
      version: 'v3',
      auth,
    });
  }
  return androidPublisherClient;
}

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

export const verifyProAndroidPurchase = onCall<
  VerifyProAndroidPurchaseRequest,
  Promise<VerifyProAndroidPurchaseResponse>
>(
  {
    region: 'asia-southeast1',
    // Gen2 callables run on Cloud Run. The endpoint must allow public invoke;
    // Firebase Auth is enforced below via request.auth (see Cloud Run 401 logs).
    invoker: 'public',
    minInstances: 0,
    timeoutSeconds: 30,
  },
  async (request) => {
    logger.info('verifyProAndroidPurchase invoked', {
      hasAuth: request.auth != null,
      uid: request.auth?.uid ?? null,
      productId:
        typeof request.data?.productId === 'string'
          ? request.data.productId
          : null,
    });

    const uid = requireAuthedUid(request.auth?.uid);
    const productId = requireString(request.data?.productId, 'productId', 128);
    assertProProductIdAllowed(productId);
    const purchaseToken = requireString(
      request.data?.purchaseToken,
      'purchaseToken',
      2048,
    );

    const packageName = env('ANDROID_PACKAGE_NAME');
    const kind = proProductKindFor(productId);

    logger.info('verifyProAndroidPurchase validated request', {
      uid,
      productId,
      kind,
      packageName,
    });

    let entitled: boolean;
    let expiresAtEpochMs: number | null;
    let resolvedProductId = productId;
    try {
      const verified =
        kind === 'subscription'
          ? await verifyAndroidSubscriptionPurchase({
              packageName,
              hintProductId: productId,
              purchaseToken,
            })
          : {
              ...(await verifyAndroidProductPurchase({
                packageName,
                productId,
                purchaseToken,
              })),
              expiresAtEpochMs: null as number | null,
              resolvedProductId: productId,
            };
      entitled = verified.entitled;
      expiresAtEpochMs = verified.expiresAtEpochMs;
      resolvedProductId = verified.resolvedProductId;
    } catch (error) {
      logger.error('Google Play verification failed', {
        uid,
        productId,
        kind,
        error: error instanceof Error ? error.message : String(error),
      });
      throw new HttpsError(
        'internal',
        'Failed to verify purchase with Google Play.',
      );
    }

    const validatedAtEpochMs = Date.now();
    logger.info('Play verification result', {
      uid,
      productId: resolvedProductId,
      clientProductId: productId,
      entitled,
      expiresAtEpochMs,
    });

    // Persist entitlement for this user (anonymous auth UID is enough) and bind
    // the purchase token to the first UID that successfully validates it.
    const purchaseTokenHash = sha256Hex(purchaseToken);
    const db = admin.firestore();
    const tokenRef = db.doc(`purchaseTokens/${purchaseTokenHash}`);
    const entitlementRef = db.doc(`users/${uid}/entitlements/pro`);
    await db.runTransaction(async (tx) => {
      const tokenSnap = await tx.get(tokenRef);
      const existingUid = tokenSnap.exists
        ? tokenSnap.get('uid') as string | undefined
        : undefined;
      if (existingUid != null && existingUid !== uid && entitled) {
        logger.info('Rebinding purchase token to uid after restore', {
          previousUid: existingUid,
          uid,
          productId: resolvedProductId,
        });
      } else {
        assertTokenOwner(existingUid, uid, entitled);
      }

      tx.set(
        tokenRef,
        {
          uid,
          platform: 'android',
          productId: resolvedProductId,
          kind,
          expiresAtEpochMs,
          packageName,
          lastEntitled: entitled,
          lastValidatedAtEpochMs: validatedAtEpochMs,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.set(
        entitlementRef,
        {
          entitled,
          platform: 'android',
          productId: resolvedProductId,
          kind,
          expiresAtEpochMs,
          packageName,
          purchaseTokenHash,
          validatedAtEpochMs,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    return {
      entitled,
      productId: resolvedProductId,
      kind,
      expiresAtEpochMs,
      packageName,
      validatedAtEpochMs,
    };
  },
);

