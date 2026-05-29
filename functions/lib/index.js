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
exports.sha256Hex = sha256Hex;
exports.proProductKindFor = proProductKindFor;
exports.assertProProductIdAllowed = assertProProductIdAllowed;
exports.assertTokenOwner = assertTokenOwner;
exports.productIdFromSubscriptionV2 = productIdFromSubscriptionV2;
exports.subscriptionEntitlementFromV2 = subscriptionEntitlementFromV2;
const admin = __importStar(require("firebase-admin"));
const node_crypto_1 = require("node:crypto");
const firebase_functions_1 = require("firebase-functions");
const https_1 = require("firebase-functions/v2/https");
const googleapis_1 = require("googleapis");
admin.initializeApp();
const PRO_CATALOG = [
    'sub_weekly',
    'sub_monthly',
    'sub_annually',
    'lifetime',
];
const PRO_PRODUCT_IDS = new Set(PRO_CATALOG);
const PRO_SUBSCRIPTION_PRODUCT_IDS = PRO_CATALOG.filter((id) => /^sub[-_]/.test(id));
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
function sha256Hex(value) {
    return (0, node_crypto_1.createHash)('sha256').update(value).digest('hex');
}
function proProductKindFor(productId) {
    return /^sub[-_]/.test(productId) ? 'subscription' : 'lifetime';
}
function assertProProductIdAllowed(productId) {
    if (!PRO_PRODUCT_IDS.has(productId)) {
        throw new https_1.HttpsError('invalid-argument', `Unsupported Pro product ID: ${productId}`);
    }
}
function assertTokenOwner(existingUid, uid, entitled) {
    if (existingUid != null && existingUid !== uid && !entitled) {
        // Do not throw: after reinstall the Firebase anonymous UID changes while
        // the Play token may still point at the old UID. Returning entitled:false
        // lets restore finish; the next successful validation can rebind.
        firebase_functions_1.logger.warn('Purchase token linked to another uid and not entitled', {
            existingUid,
            uid,
        });
    }
}
let androidPublisherClient = null;
function getAndroidPublisherClient() {
    if (androidPublisherClient == null) {
        // Reuse one client per function instance; GoogleAuth caches ADC tokens.
        const auth = new googleapis_1.google.auth.GoogleAuth({
            scopes: ['https://www.googleapis.com/auth/androidpublisher'],
        });
        androidPublisherClient = googleapis_1.google.androidpublisher({
            version: 'v3',
            auth,
        });
    }
    return androidPublisherClient;
}
async function verifyAndroidProductPurchase(params) {
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
function productIdFromSubscriptionV2(data) {
    for (const item of data.lineItems ?? []) {
        const productId = item.productId?.trim();
        if (productId) {
            return productId;
        }
    }
    return null;
}
function subscriptionEntitlementFromV2(data) {
    const state = data.subscriptionState ?? '';
    if (!ACTIVE_SUBSCRIPTION_STATES.has(state)) {
        return { entitled: false, expiresAtEpochMs: null };
    }
    let expiresAtEpochMs = null;
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
async function verifyAndroidSubscriptionPurchase(params) {
    const androidpublisher = getAndroidPublisherClient();
    // Play Billing v5+ subscriptions require the subscriptionsv2 API (token only).
    try {
        const v2 = await androidpublisher.purchases.subscriptionsv2.get({
            packageName: params.packageName,
            token: params.purchaseToken,
        });
        const entitlement = subscriptionEntitlementFromV2(v2.data);
        const resolvedProductId = productIdFromSubscriptionV2(v2.data) ?? params.hintProductId;
        return { ...entitlement, resolvedProductId };
    }
    catch (v2Error) {
        firebase_functions_1.logger.warn('subscriptionsv2.get failed; falling back to subscriptions.get', {
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
            const expiresAtEpochMs = typeof expiryTimeMillis === 'string' ? Number(expiryTimeMillis) : null;
            const entitled = expiresAtEpochMs != null && Number.isFinite(expiresAtEpochMs)
                ? Date.now() < expiresAtEpochMs
                : false;
            if (entitled) {
                return {
                    entitled: true,
                    expiresAtEpochMs,
                    resolvedProductId: subscriptionId,
                };
            }
        }
        catch (fallbackError) {
            firebase_functions_1.logger.debug('subscriptions.get failed for candidate product', {
                subscriptionId,
                error: fallbackError instanceof Error
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
exports.verifyProAndroidPurchase = (0, https_1.onCall)({
    region: 'asia-southeast1',
    // Gen2 callables run on Cloud Run. The endpoint must allow public invoke;
    // Firebase Auth is enforced below via request.auth (see Cloud Run 401 logs).
    invoker: 'public',
    minInstances: 0,
    timeoutSeconds: 30,
}, async (request) => {
    firebase_functions_1.logger.info('verifyProAndroidPurchase invoked', {
        hasAuth: request.auth != null,
        uid: request.auth?.uid ?? null,
        productId: typeof request.data?.productId === 'string'
            ? request.data.productId
            : null,
    });
    const uid = requireAuthedUid(request.auth?.uid);
    const productId = requireString(request.data?.productId, 'productId', 128);
    assertProProductIdAllowed(productId);
    const purchaseToken = requireString(request.data?.purchaseToken, 'purchaseToken', 2048);
    const packageName = env('ANDROID_PACKAGE_NAME');
    const kind = proProductKindFor(productId);
    firebase_functions_1.logger.info('verifyProAndroidPurchase validated request', {
        uid,
        productId,
        kind,
        packageName,
    });
    let entitled;
    let expiresAtEpochMs;
    let resolvedProductId = productId;
    try {
        const verified = kind === 'subscription'
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
                expiresAtEpochMs: null,
                resolvedProductId: productId,
            };
        entitled = verified.entitled;
        expiresAtEpochMs = verified.expiresAtEpochMs;
        resolvedProductId = verified.resolvedProductId;
    }
    catch (error) {
        firebase_functions_1.logger.error('Google Play verification failed', {
            uid,
            productId,
            kind,
            error: error instanceof Error ? error.message : String(error),
        });
        throw new https_1.HttpsError('internal', 'Failed to verify purchase with Google Play.');
    }
    const validatedAtEpochMs = Date.now();
    firebase_functions_1.logger.info('Play verification result', {
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
            ? tokenSnap.get('uid')
            : undefined;
        if (existingUid != null && existingUid !== uid && entitled) {
            firebase_functions_1.logger.info('Rebinding purchase token to uid after restore', {
                previousUid: existingUid,
                uid,
                productId: resolvedProductId,
            });
        }
        else {
            assertTokenOwner(existingUid, uid, entitled);
        }
        tx.set(tokenRef, {
            uid,
            platform: 'android',
            productId: resolvedProductId,
            kind,
            expiresAtEpochMs,
            packageName,
            lastEntitled: entitled,
            lastValidatedAtEpochMs: validatedAtEpochMs,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        tx.set(entitlementRef, {
            entitled,
            platform: 'android',
            productId: resolvedProductId,
            kind,
            expiresAtEpochMs,
            packageName,
            purchaseTokenHash,
            validatedAtEpochMs,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
    return {
        entitled,
        productId: resolvedProductId,
        kind,
        expiresAtEpochMs,
        packageName,
        validatedAtEpochMs,
    };
});
