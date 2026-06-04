import * as admin from 'firebase-admin';

admin.initializeApp();

export {
  assertProProductIdAllowed,
  assertTokenOwner,
  proProductKindFor,
  sha256Hex,
} from './pro/helpers.js';
export {
  productIdFromSubscriptionV2,
  subscriptionEntitlementFromV2,
} from './android/subscription-v2.js';
export { verifyProAndroidPurchase } from './handlers/verify-pro-android-purchase.js';
