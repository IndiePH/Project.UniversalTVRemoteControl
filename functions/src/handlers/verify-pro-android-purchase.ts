import { logger } from 'firebase-functions';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { verifyProAndroidPlayPurchase } from '../android/play-verification.js';
import {
  env,
  requireAuthedUid,
  requireString,
} from '../callable/request-validation.js';
import { persistProAndroidEntitlement } from '../entitlement/persist-pro-android.js';
import {
  assertProProductIdAllowed,
  proProductKindFor,
} from '../pro/helpers.js';

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
    let resolvedProductId: string;
    try {
      const verified = await verifyProAndroidPlayPurchase({
        packageName,
        productId,
        purchaseToken,
        kind,
      });
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

    await persistProAndroidEntitlement({
      uid,
      purchaseToken,
      resolvedProductId,
      kind,
      entitled,
      expiresAtEpochMs,
      packageName,
      validatedAtEpochMs,
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
