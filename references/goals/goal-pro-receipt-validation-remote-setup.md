# Goal: Pro receipt validation — remote setup

**Status:** pending (operator / release task)  
**Firebase project:** `oneremote-497701`  
**Android package:** `com.vorithstudio.smarttvremote`  
**Callable function:** `verifyProAndroidPurchase`  
**Functions region:** `asia-southeast1` (must match Flutter client)  
**Code:** `functions/src/index.ts`, `lib/app/monetization/pro_receipt_validation_service.dart`

## Scope

Deploy and configure server-side Google Play receipt validation for Pro purchases. The Flutter app calls the callable after purchase/restore; entitlement is written to Firestore by the function.

**Node.js 24** is required on the machine that builds and deploys `functions/` — not for running the Flutter app.

---

## 1. Prerequisites on your machine

1. Install [Node.js 24](https://nodejs.org/) (matches `functions/package.json` `engines.node`).
2. Install Firebase CLI:
   ```powershell
   npm install -g firebase-tools
   ```
3. Log in:
   ```powershell
   npx firebase-tools@latest login
   ```
4. From the repo root (`one_remote`), link the Firebase project (create `.firebaserc` if missing):
   ```powershell
   npx firebase-tools@latest use --add oneremote-497701
   ```
   Choose `default` when prompted.

---

## 2. Enable Firebase / Google Cloud services

In [Firebase Console](https://console.firebase.google.com/) → project **oneremote-497701**:

| Service | Why |
|--------|-----|
| **Authentication** → Sign-in method → **Anonymous** | App calls `signInAnonymously()` before validation (`ProReceiptValidationService`) |
| **Firestore** | Function writes `users/{uid}/entitlements/pro` and `purchaseTokens/{hash}` |
| **Functions** | Hosts `verifyProAndroidPurchase` |

In [Google Cloud Console](https://console.cloud.google.com/) → same project → **APIs & Services → Library**, enable:

- **Google Play Android Developer API** (required for receipt checks)
- **Cloud Functions API**
- **Cloud Run API** (2nd gen functions use Cloud Run)
- **Cloud Build API**
- **Artifact Registry API**

**Billing:** Firebase project must be on the **Blaze (pay-as-you-go)** plan to deploy Functions and call external APIs.

---

## 3. Google Play Console → grant API access

Play does **not** use a normal GCP IAM role alone; you grant access inside Play Console.

1. Open [Google Play Console](https://play.google.com/console/) → your app.
2. **Setup** → **API access** (or **Users and permissions** → **API access**).
3. **Link** the Google Cloud project `oneremote-497701` if not already linked.
4. Find the service account your Cloud Function runs as. After first deploy (step 6), confirm in **Google Cloud Console → Cloud Run** → service for `verifyproandroidpurchase` → **Security** → service account. Common candidates:
   - `oneremote-497701@appspot.gserviceaccount.com`
   - `PROJECT_NUMBER-compute@developer.gserviceaccount.com`
5. In Play Console, for that service account, grant at least:
   - **View app information and download bulk reports** (minimum for verification)
   - **View financial data, orders, and cancellation survey responses** (recommended for subscriptions)
6. Confirm Play **product IDs** match the app (`AppMonetizationDiConfig.proProductIds`):
   - `sub_weekly`, `sub_monthly`, `sub_annually`, `lifetime`
7. Add test Google accounts under **Setup → License testing** for sandbox purchases.

---

## 4. Set the Functions environment variable

The function reads `ANDROID_PACKAGE_NAME` from the environment (`functions/src/index.ts`).

1. In `functions/`, create:

   **File:** `functions/.env.oneremote-497701`

   ```env
   ANDROID_PACKAGE_NAME=com.vorithstudio.smarttvremote
   ```

   (Same value as `functions/.env.example`.)

2. Optional: keep env files out of git (add to `.gitignore`):

   ```
   functions/.env*
   !functions/.env.example
   ```

Firebase loads `functions/.env.<projectId>` on deploy for 2nd gen functions.

---

## 5. Build and deploy Functions

Always pass `--project oneremote-497701`. The Firebase CLI can target a different active project (for example another app in the same login) even when `.firebaserc` lists this one.

```powershell
cd functions
npm install
cd ..
npx firebase-tools@latest deploy --only functions --project oneremote-497701
```

The first line of output must be `=== Deploying to 'oneremote-497701'...`. If it names any other project, stop with Ctrl+C.

`firebase.json` runs `npm run build` in `functions/` via `predeploy` before upload. For local emulator or `npm test`, run `npm run build` in `functions/` after changing `src/`.

A Node.js **runtime-only** change (for example `engines.node` in `functions/package.json`) does not require a new Play/app build. Existing installs keep calling the same callable.

Expected deploy output includes:

`verifyProAndroidPurchase(asia-southeast1)`

and an update line such as `updating Node.js 24 (2nd Gen) function verifyProAndroidPurchase(asia-southeast1)`.

---

## 6. Verify deployment in console

1. **Firebase Console → Build → Functions**
   - Function: `verifyProAndroidPurchase`
   - Region: `asia-southeast1`
   - Runtime: **Node.js 24** (Additional details)
2. **Google Cloud Console → Cloud Run**
   - Service exists and is healthy.

---

## 7. Confirm the Flutter app matches

Already wired in the repo:

| Item | Value |
|------|--------|
| Callable name | `verifyProAndroidPurchase` |
| Region | `asia-southeast1` (`ProReceiptValidationService.functionsRegion`) |
| Firebase init | `main.dart` |
| Validation platform | Android only, when Firebase is initialized |

Rebuild and install on a **real Android device** with Google Play (license tester account):

```powershell
flutter run
# or
flutter build apk --release
```

---

## 8. End-to-end test on device

1. Anonymous auth runs automatically on first validation.
2. Open app → **Settings** → **Upgrade to Pro** (or trigger a locked Pro feature).
3. Complete a **license tester** purchase in Play.
4. Verify:

   **Firebase Console → Functions → Logs**
   - `verifyProAndroidPurchase` invocations
   - `Missing required env var: ANDROID_PACKAGE_NAME` → redeploy with `.env.oneremote-497701`
   - Play API 403 → service account not granted in Play Console
   - `permission-denied` + token already linked → token bound to another Firebase UID (anti-replay)

   **Firestore**
   - `users/{uid}/entitlements/pro` → `entitled: true`
   - `purchaseTokens/{hash}` → `uid`, `productId`, etc.

5. Pro status should activate in app; restore should work on the same Google Play account.

---

## 9. Firestore rules (recommended)

The app does not read entitlement docs from the client today (Admin SDK writes server-side). If you later read them from Flutter, use rules like:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/entitlements/{doc} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if false;
    }
    match /purchaseTokens/{tokenId} {
      allow read, write: if false;
    }
  }
}
```

Deploy only if you add `firestore.rules` and `firebase deploy --only firestore`.

---

## 10. Troubleshooting

| Symptom | Likely fix |
|--------|------------|
| `UNAUTHENTICATED` | Enable **Anonymous** auth in Firebase |
| `failed-precondition` + `ANDROID_PACKAGE_NAME` | Create `functions/.env.oneremote-497701` and redeploy |
| `NOT_FOUND` / wrong region | Redeploy; confirm region `asia-southeast1` |
| Play API 401/403 | Link GCP in Play Console; grant service account access |
| `Unsupported Pro product ID` | Play product ID must match app catalog |
| Purchase completes but not Pro | Check Functions logs; validation may be failing |
| Works on one phone, not another | Different Google account or token linked to another UID |

---

## Quick command checklist

```powershell
# Once, from repo root
npx firebase-tools@latest login
npx firebase-tools@latest use --add oneremote-497701

# Create functions/.env.oneremote-497701 with ANDROID_PACKAGE_NAME=...

cd functions
npm install
cd ..
npx firebase-tools@latest deploy --only functions
```

Deploy runs `npm run build` via `firebase.json` `predeploy`.

Then complete **Play Console API access** (section 3) and **device test** (section 8).

**Later:** Firebase App Check (section 11) — not required for initial receipt validation deploy.

---

## 11. Firebase App Check (later)

Protect Firebase backends (callable, Firestore) from scripted abuse and fake clients. Complements Play receipt validation; does not replace it.

**Status:** deferred — implement after section 8 passes on device.

- [ ] **Firebase Console → App Check → One Remote aOS** (`com.vorithstudio.smarttvremote`): register **Play Integrity**
- [ ] Add **SHA-256 certificate fingerprints** (extract from release keystore via `keytool -list -v`; add Play Console **App integrity → App signing** fingerprint if using Play App Signing — not the keystore password)
- [ ] Save Play Integrity config (default: **PLAY_RECOGNIZED** on; **LICENSED** off unless needed)
- [ ] Add **`firebase_app_check`** to Flutter; activate Play Integrity provider on Android startup (after Firebase init)
- [ ] Register **debug tokens** in App Check for local/dev builds (Play Integrity fails on emulators and unsigned sideloads)
- [ ] Set **`enforceAppCheck: true`** on `verifyProAndroidPurchase` in `functions/src/index.ts`
- [ ] Firebase Console → App Check → **Enforce** for **Cloud Functions** and **Firestore** (start with metrics/monitoring if unsure, then enforce)
- [ ] Re-test purchase + restore on a **Play-distributed** build after enforcement

**Code touchpoints:** `main.dart`, `functions/src/index.ts`, `pubspec.yaml`

---

## Why Node.js 24?

Only for the `functions/` backend — `npm install`, `npm test` (builds TypeScript), and `firebase deploy --only functions` (also builds via `predeploy`). Run `npm run build` locally when using the emulator or after editing `src/` without deploying. The Flutter app uses Dart only; it does not require Node on the developer machine except when working on Cloud Functions.
