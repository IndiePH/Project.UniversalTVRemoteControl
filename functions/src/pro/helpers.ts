import { createHash } from 'node:crypto';
import { logger } from 'firebase-functions';
import { HttpsError } from 'firebase-functions/v2/https';
import { PRO_PRODUCT_IDS } from './catalog.js';

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
