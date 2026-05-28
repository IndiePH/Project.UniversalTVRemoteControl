import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { google } from 'googleapis';

admin.initializeApp();

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

async function verifyAndroidProductPurchase(params: {
  packageName: string;
  productId: string;
  purchaseToken: string;
}): Promise<{ entitled: boolean }> {
  // Uses Application Default Credentials (service account) in Cloud Functions.
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const androidpublisher = google.androidpublisher({
    version: 'v3',
    auth,
  });

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
  subscriptionId: string;
  purchaseToken: string;
}): Promise<{ entitled: boolean; expiresAtEpochMs: number | null }> {
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const androidpublisher = google.androidpublisher({
    version: 'v3',
    auth,
  });

  const res = await androidpublisher.purchases.subscriptions.get({
    packageName: params.packageName,
    subscriptionId: params.subscriptionId,
    token: params.purchaseToken,
  });

  const expiryTimeMillis = res.data.expiryTimeMillis;
  const expiresAtEpochMs =
    typeof expiryTimeMillis === 'string' ? Number(expiryTimeMillis) : null;

  const entitled =
    expiresAtEpochMs != null && Number.isFinite(expiresAtEpochMs)
      ? Date.now() < expiresAtEpochMs
      : false;

  return { entitled, expiresAtEpochMs: entitled ? expiresAtEpochMs : null };
}

export const verifyProAndroidPurchase = onCall<
  VerifyProAndroidPurchaseRequest,
  Promise<VerifyProAndroidPurchaseResponse>
>(
  {
    region: 'asia-southeast1',
    // Keep warm-ish; this is a small function but may call Play APIs.
    minInstances: 0,
    timeoutSeconds: 30,
  },
  async (request) => {
    const uid = requireAuthedUid(request.auth?.uid);
    const productId = requireString(request.data?.productId, 'productId', 128);
    const purchaseToken = requireString(
      request.data?.purchaseToken,
      'purchaseToken',
      2048,
    );

    const packageName = env('ANDROID_PACKAGE_NAME');

    const isSubscription = productId.startsWith('sub-');
    const kind: 'lifetime' | 'subscription' = isSubscription
      ? 'subscription'
      : 'lifetime';

    // Verify with Google Play.
    const { entitled, expiresAtEpochMs } = isSubscription
      ? await verifyAndroidSubscriptionPurchase({
          packageName,
          subscriptionId: productId,
          purchaseToken,
        })
      : {
          ...(await verifyAndroidProductPurchase({
            packageName,
            productId,
            purchaseToken,
          })),
          expiresAtEpochMs: null,
        };

    const validatedAtEpochMs = Date.now();

    // Persist entitlement for this user (anonymous auth UID is enough).
    await admin
      .firestore()
      .doc(`users/${uid}/entitlements/pro`)
      .set(
        {
          entitled,
          platform: 'android',
          productId,
          kind,
          expiresAtEpochMs,
          packageName,
          validatedAtEpochMs,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

    return {
      entitled,
      productId,
      kind,
      expiresAtEpochMs,
      packageName,
      validatedAtEpochMs,
    };
  },
);

