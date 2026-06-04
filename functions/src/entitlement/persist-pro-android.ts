import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions';
import { assertTokenOwner, sha256Hex } from '../pro/helpers.js';

export type PersistProAndroidEntitlementParams = {
  uid: string;
  purchaseToken: string;
  resolvedProductId: string;
  kind: 'lifetime' | 'subscription';
  entitled: boolean;
  expiresAtEpochMs: number | null;
  packageName: string;
  validatedAtEpochMs: number;
};

export async function persistProAndroidEntitlement(
  params: PersistProAndroidEntitlementParams,
): Promise<void> {
  const purchaseTokenHash = sha256Hex(params.purchaseToken);
  const db = admin.firestore();
  const tokenRef = db.doc(`purchaseTokens/${purchaseTokenHash}`);
  const entitlementRef = db.doc(`users/${params.uid}/entitlements/pro`);

  await db.runTransaction(async (tx) => {
    const tokenSnap = await tx.get(tokenRef);
    const existingUid = tokenSnap.exists
      ? (tokenSnap.get('uid') as string | undefined)
      : undefined;

    if (existingUid != null && existingUid !== params.uid && params.entitled) {
      logger.info('Rebinding purchase token to uid after restore', {
        previousUid: existingUid,
        uid: params.uid,
        productId: params.resolvedProductId,
      });
    } else {
      assertTokenOwner(existingUid, params.uid, params.entitled);
    }

    tx.set(
      tokenRef,
      {
        uid: params.uid,
        platform: 'android',
        productId: params.resolvedProductId,
        kind: params.kind,
        expiresAtEpochMs: params.expiresAtEpochMs,
        packageName: params.packageName,
        lastEntitled: params.entitled,
        lastValidatedAtEpochMs: params.validatedAtEpochMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    tx.set(
      entitlementRef,
      {
        entitled: params.entitled,
        platform: 'android',
        productId: params.resolvedProductId,
        kind: params.kind,
        expiresAtEpochMs: params.expiresAtEpochMs,
        packageName: params.packageName,
        purchaseTokenHash,
        validatedAtEpochMs: params.validatedAtEpochMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}
