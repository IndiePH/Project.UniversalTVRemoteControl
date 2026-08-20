# Guide: Personal Sideload Build

**Branch:** `personal-build` (created from `main`)
**Purpose:** a build for **one specific device**, sideloaded outside the Play Store, with Pro
entitlement forced on and telemetry reporting disabled. Not for distribution.

---

## Steps: update and rebuild

Follow these in order, top to bottom. Steps 7–8 only apply the first time you build on a
given machine, or after you've lost the keystore from a previous build — skip straight to
step 9 otherwise.

1. **Switch to `main` and update it.**
   ```bash
   git checkout main
   git fetch
   git pull
   ```

2. **Switch to `personal-build`.**
   ```bash
   git checkout personal-build
   ```

3. **Merge `main` in.**
   ```bash
   git merge main
   ```

4. **Resolve conflicts, if any.** Git will stop and tell you which files conflict. Expect
   conflicts only in the 4 files this branch touches (see the table under "How it works"
   below) — only if `main` happened to change the same lines. Open each conflicted file,
   keep the `PERSONAL_BUILD` flag guard intact while merging in whatever `main` changed
   around it, then:
   ```bash
   git add <resolved files>
   git commit
   ```
   If there were no conflicts, the merge already committed itself — nothing to do here.

5. **Sanity-check the merge compiles.**
   ```bash
   flutter pub get
   flutter analyze
   ```
   Should report 0 issues. If not, something in the merge needs fixing before continuing.

6. **Re-check whether this branch's bypass is still complete.** If `main` added Firebase
   App Check / Play Integrity since the branch last synced, it needs a new guard here too
   — see "Why this branch exists" below for what to grep for.

7. **(First build on this machine only) Generate a throwaway signing key.**
   ```bash
   keytool -genkeypair -v \
     -keystore android/app/personal-release-key.jks \
     -alias personalbuild \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -storepass <password> -keypass <password> \
     -dname "CN=Personal Build, OU=Personal, O=Personal, L=NA, ST=NA, C=US"
   ```

8. **(Same first-time case) Point Gradle at it** — create `android/key.properties`:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=personalbuild
   storeFile=app/personal-release-key.jks
   ```
   Both files are gitignored — back them up outside the repo. See "If you lose the
   keystore" below before regenerating one on a machine that already has the app installed
   on the phone.

9. **Build.**
   ```bash
   flutter build apk --release --dart-define=PERSONAL_BUILD=true
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`

10. **Verify it's signed with the expected keystore.** Compare the APK's certificate
    fingerprint against the keystore's — if `key.properties` silently pointed at the wrong
    file, or a stale `key.properties.example` got used by mistake, this catches it before
    you install:
    ```bash
    BT=$(ls -d /home/ubuntu/Android/Sdk/build-tools/*/ | sort -V | tail -1)
    "${BT}apksigner" verify --print-certs build/app/outputs/flutter-apk/app-release.apk

    keytool -list -v -keystore android/app/personal-release-key.jks \
      -storepass "$(grep storePassword android/key.properties | cut -d= -f2)" \
      | grep -A1 "SHA256:"
    ```
    The `SHA-256 digest` from `apksigner` and the `SHA256:` fingerprint from `keytool` must
    match exactly. If they don't, stop — something is wrong with the signing config, and
    installing anyway risks Android rejecting the update (or worse, silently accepting an
    unexpected signer if this is ever run somewhere less controlled than your own machine).

11. **Install on the phone.**
    ```bash
    adb install -r build/app/outputs/flutter-apk/app-release.apk
    ```

---

## Why this branch exists

Two things were requested that don't belong on `main`:

1. **Pro unlocked without a store purchase.** Normal builds resolve entitlement through
   `StoreProEntitlementRepository` (real Google Play Billing + server-side receipt
   validation via `verifyProAndroidPurchase`, see `references/goals/goal-pro-receipt-validation-remote-setup.md`).
2. **No telemetry.** Firebase Analytics events and Crashlytics reports are suppressed.

**Play Integrity / Firebase App Check was not stripped, because it was never implemented.**
Checked at the time this branch was created — no references anywhere in the codebase
(`app_check`, `play_integrity`, `AppCheck`, `integrity` all zero matches). The setup doc's
§11 marks it explicitly **deferred**. Re-check this with the same grep after every merge
from `main` (step 6 above) — if it's been added, this branch needs a new bypass for it.

---

## How it works

Everything is gated behind a single compile-time flag, following the project's existing
`--dart-define` convention (see README "Current Runtime Modes") rather than a Gradle flavor:

```dart
// lib/app/configurations/app_build_config.dart
static const bool personalBuildUnlock = bool.fromEnvironment(
  'PERSONAL_BUILD',
  defaultValue: false,
);
```

Defaults to `false`, so a normal `flutter build apk --release` (no dart-define) is
byte-for-byte the same code path as `main`. It only changes behavior when built with
`--dart-define=PERSONAL_BUILD=true`.

**Files that branch on the flag** (these are the ones most likely to conflict on merge):

| File | What changes when `PERSONAL_BUILD=true` |
|---|---|
| `lib/app/configurations/app_monetization_di_config.dart` | `_buildRepository()` returns `FakeProEntitlementRepository(initialStatus: entitled)` instead of the real store repository. Skips constructing `ProReceiptValidationService` entirely (`_needsReceiptValidation`). |
| `lib/main.dart` | Calls `FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false)` at startup, and skips `recordFlutterFatalError` / `recordError` in the two error handlers (belt-and-suspenders — collection-disable timing isn't guaranteed mid-session on every SDK version). |
| `lib/app/analytics/analytics_service.dart` | `_tryAnalytics()` returns `null` when the flag is set, so `logEvent` becomes a no-op. |
| `lib/app/configurations/app_build_config.dart` | Declares the flag itself. |

`Firebase.initializeApp()` itself is **not** skipped — `AdRemoteConfigService` depends on
Firebase being initialized for ad test-mode detection, and disabling it would break ads.

---

## If you lose the keystore

`android/app/personal-release-key.jks` and `android/key.properties` are gitignored — they
exist only on the machine that generated them. If you lose them and generate a new
keystore (step 7–8):

- The new one will have a **different signature**.
- Android refuses to install an APK signed with a different key over an app with the same
  `applicationId` (`com.vorithstudio.smarttvremote`) already installed.
- You'd have to **uninstall the existing app from the phone first**, losing local app data
  (paired TVs, preferences) before sideloading the new build.

Back up `personal-release-key.jks` and `key.properties` outside the repo to avoid this.

---

## Long-term maintenance

There is no CI or test coverage specific to `PERSONAL_BUILD=true` — `flutter analyze` (step
5) plus a manual sideload/launch check is the whole verification loop after each merge.
Merge `main` in periodically (don't let it drift for months) — the longer it diverges, the
more likely a real conflict shows up in `app_monetization_di_config.dart` if that file gets
refactored upstream.
