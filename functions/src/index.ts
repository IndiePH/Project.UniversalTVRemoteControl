import * as admin from 'firebase-admin';

admin.initializeApp();

export { verifyProAndroidPurchase } from './handlers/verify-pro-android-purchase.js';
