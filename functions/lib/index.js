"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyProAndroidPurchase = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const googleapis_1 = require("googleapis");
admin.initializeApp();
function requireString(value, name, maxLen) {
    if (typeof value !== 'string') {
        throw new https_1.HttpsError('invalid-argument', `${name} must be a string`);
    }
    const trimmed = value.trim();
    if (!trimmed) {
        throw new https_1.HttpsError('invalid-argument', `${name} is required`);
    }
    if (trimmed.length > maxLen) {
        throw new https_1.HttpsError('invalid-argument', `${name} is too long`);
    }
    return trimmed;
}
function requireAuthedUid(uid) {
    if (!uid) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    }
    return uid;
}
function env(name) {
    const v = process.env[name];
    if (!v || !v.trim()) {
        throw new https_1.HttpsError('failed-precondition', `Missing required env var: ${name}`);
    }
    return v.trim();
}
async function verifyAndroidProductPurchase(params) {
    // Uses Application Default Credentials (service account) in Cloud Functions.
    const auth = new googleapis_1.google.auth.GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const androidpublisher = googleapis_1.google.androidpublisher({
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
async function verifyAndroidSubscriptionPurchase(params) {
    const auth = new googleapis_1.google.auth.GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const androidpublisher = googleapis_1.google.androidpublisher({
        version: 'v3',
        auth,
    });
    const res = await androidpublisher.purchases.subscriptions.get({
        packageName: params.packageName,
        subscriptionId: params.subscriptionId,
        token: params.purchaseToken,
    });
    const expiryTimeMillis = res.data.expiryTimeMillis;
    const expiresAtEpochMs = typeof expiryTimeMillis === 'string' ? Number(expiryTimeMillis) : null;
    const entitled = expiresAtEpochMs != null && Number.isFinite(expiresAtEpochMs)
        ? Date.now() < expiresAtEpochMs
        : false;
    return { entitled, expiresAtEpochMs: entitled ? expiresAtEpochMs : null };
}
exports.verifyProAndroidPurchase = (0, https_1.onCall)({
    region: 'asia-southeast1',
    // Keep warm-ish; this is a small function but may call Play APIs.
    minInstances: 0,
    timeoutSeconds: 30,
}, async (request) => {
    const uid = requireAuthedUid(request.auth?.uid);
    const productId = requireString(request.data?.productId, 'productId', 128);
    const purchaseToken = requireString(request.data?.purchaseToken, 'purchaseToken', 2048);
    const packageName = env('ANDROID_PACKAGE_NAME');
    const isSubscription = productId.startsWith('sub-');
    const kind = isSubscription
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
        .set({
        entitled,
        platform: 'android',
        productId,
        kind,
        expiresAtEpochMs,
        packageName,
        validatedAtEpochMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        entitled,
        productId,
        kind,
        expiresAtEpochMs,
        packageName,
        validatedAtEpochMs,
    };
});
