# Guide: Personal Sideload Build

**Branch:** `personal-build` (created from `main`)
**Purpose:** a build for **one specific device**, sideloaded outside the Play Store, with Pro
entitlement forced on and telemetry reporting disabled. Not for distribution.

> **This branch must NEVER be merged into `main`.** Everything below — the entitlement
> bypass, the telemetry suppression, the `PERSONAL_BUILD` env var and manifest
> placeholders — exists solely for one sideloaded personal device. None of it belongs in
> a Play Store release. Merge `main` *into* `personal-build` (step 3 below), never the
> reverse.

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
   conflicts only in the files this branch touches (see the table under "How it works"
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
   PERSONAL_BUILD=true flutter build apk --release --dart-define=PERSONAL_BUILD=true
   ```
   Both flags are required — the `PERSONAL_BUILD` env var and the `--dart-define` gate
   different layers (Gradle/manifest vs. Dart) and neither can see the other. See "How it
   works" below.

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
2. **No network activity unrelated to remote-control functionality.** Firebase Analytics,
   Crashlytics, and Unity LevelPlay's ad SDK init are all suppressed — see "How it works"
   below for what's disabled and how completely.

**Play Integrity / Firebase App Check was not stripped, because it was never implemented.**
Checked at the time this branch was created — no references anywhere in the codebase
(`app_check`, `play_integrity`, `AppCheck`, `integrity` all zero matches). The setup doc's
§11 marks it explicitly **deferred**. Re-check this with the same grep after every merge
from `main` (step 6 above) — if it's been added, this branch needs a new bypass for it.

---

## How it works

This branch is gated behind **two** build-time signals, not one — this is the one
deliberate exception to the project's `--dart-define`-only convention (see README
"Current Runtime Modes"), and it exists because Dart-layer flags are invisible to
Gradle/the Android manifest:

```dart
// lib/app/configurations/app_build_config.dart
static const bool personalBuildUnlock = bool.fromEnvironment(
  'PERSONAL_BUILD',
  defaultValue: false,
);
```

```kotlin
// android/app/build.gradle.kts
val personalBuild = (System.getenv("PERSONAL_BUILD") ?: "false").toBoolean()
```

Both default to `false`/off, so a normal `flutter build apk --release` (no env var, no
dart-define) is byte-for-byte the same code path as `main`. Both must be set — see the
build command in step 9 — because they gate different layers and neither can see the
other:

- `--dart-define=PERSONAL_BUILD=true` gates app-level Dart behavior (entitlement, ad
  display, explicit analytics calls, ad SDK init).
- `PERSONAL_BUILD=true` (the env var) gates two `AndroidManifest.xml` meta-data values via
  Gradle `manifestPlaceholders`, so Firebase Analytics/Crashlytics never auto-collect in
  the first place — see "Why two flags" below for why the Dart one alone isn't enough.

**Files that branch on one flag or the other** (these are the ones most likely to conflict
on merge):

| File | Flag | What changes when set |
|---|---|---|
| `lib/app/configurations/app_monetization_di_config.dart` | dart-define | `_buildRepository()` returns `FakeProEntitlementRepository(initialStatus: entitled)` instead of the real store repository. Skips constructing `ProReceiptValidationService` entirely (`_needsReceiptValidation`) — so `firebase_auth`/`cloud_functions` are never touched. |
| `lib/main.dart` | dart-define | Calls `FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false)` and `FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false)` at startup (belt-and-suspenders on top of the manifest values below); skips `recordFlutterFatalError`/`recordError` in the two error handlers; skips Unity LevelPlay SDK init (`_initializeLevelPlayAds()`) entirely — no ad-network calls, even though ads never show for a forced-Pro user anyway. |
| `lib/app/analytics/analytics_service.dart` | dart-define | `_tryAnalytics()` returns `null`, so `logEvent` becomes a no-op. |
| `lib/app/configurations/app_build_config.dart` | dart-define | Declares the Dart flag itself. |
| `android/app/build.gradle.kts` | env var | Declares `personalBuild`; sets `analyticsCollectionDeactivated`/`crashlyticsCollectionEnabled` manifest placeholders. |
| `android/app/src/main/AndroidManifest.xml` | env var (via placeholder) | `firebase_analytics_collection_deactivated` / `firebase_crashlytics_collection_enabled` meta-data — read by the native SDKs before any Dart code runs. |

`Firebase.initializeApp()` itself is **not** skipped — `FirebaseCrashlytics`/`FirebaseAnalytics`
need Firebase initialized before their collection can be turned off (see `main.dart` above),
and some plugin init paths assume it's been called.

### Why two flags — the pre-Dart-init gap

Firebase Analytics and Crashlytics auto-initialize via a native Android `ContentProvider`
the instant the app process starts — before Flutter's engine attaches and before `main()`
runs. A Dart-only flag (`setAnalyticsCollectionEnabled(false)` /
`setCrashlyticsCollectionEnabled(false)` in `main.dart`) can only act *after* that native
auto-init has already happened, leaving a small window where the SDK could collect before
being told to stop. The manifest meta-data closes that window — the SDKs read
`firebase_analytics_collection_deactivated` / `firebase_crashlytics_collection_enabled`
from their own `ContentProvider.onCreate()`, before Dart ever runs. Unity LevelPlay doesn't
have this problem — it only makes network calls when `LevelPlayAdsService.initialize()` (a
Dart-level call) is explicitly invoked, so skipping that call in `_initializeLevelPlayAds()`
is already a complete fix.

Verified by inspecting the merged manifest baked into each APK variant
(`aapt2 dump xmltree ... --file AndroidManifest.xml`):
`PERSONAL_BUILD=true` → `analytics_collection_deactivated=true`,
`crashlytics_collection_enabled=false`; no env var → `false`/`true` (Firebase's own
defaults, i.e. unchanged from `main`).

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

Two things worth remembering about the Gradle/manifest piece specifically:

- Forgetting the `PERSONAL_BUILD=` env var at build time (step 9) silently falls back to
  the production manifest values — the APK still builds and installs fine, it just quietly
  keeps Analytics/Crashlytics on. Rerun step 9 with the env var if in doubt; you can confirm
  either way with the `aapt2 dump xmltree` check described under "How it works" above.
- This is the one place this branch's changes live outside `lib/` — if `main` ever adds its
  own `manifestPlaceholders` entries in `android/app/build.gradle.kts`, that's a merge
  conflict to resolve carefully rather than something `flutter analyze` will catch.

---

## Archive: pre-LevelPlay ad stack (superseded 2026-08-27)

`main` switched its ad implementation from AdMob/UMP to Unity LevelPlay in commit `8a52e47`
("feat: Unity LevelPlay ads, Android fixes, and Crashlytics hardening (#30)"). Before that
merge, this branch's ad-related bypass points looked different — kept here for history since
they no longer exist in the codebase:

- `lib/app/configurations/di_bootstrap.dart` used to skip `AdRemoteConfigService
  .fetchAndActivate()` — a Firebase Remote Config fetch that toggled the `test_ads_enabled`
  flag consumed by `AdConfig`. `main` deleted `AdRemoteConfigService` and the Remote Config
  ads toggle entirely in `8a52e47`, so there was nothing left to skip; this file dropped out
  of the guarded-files table.
- `lib/main.dart` used to skip an AdMob/UMP consent-gathering + `MobileAds.instance
  .initialize()` block, gated by `AdConsentCoordinator` (`lib/app/compliance
  /ad_consent_coordinator.dart`, also deleted in `8a52e47`). That block is now replaced by
  the Unity LevelPlay init described in the table above.
- `android/app/build.gradle.kts` declared `productionAdMobAppId` and set it via
  `manifestPlaceholders["admobAppId"]`, consumed by `AndroidManifest.xml`'s
  `com.google.android.gms.ads.APPLICATION_ID` meta-data. All three were removed as dead code
  once AdMob was gone — LevelPlay doesn't use an AndroidManifest-level application ID.
- `lib/app/ads/interstitial_ad_controller.dart` and `lib/app/ads/interstitial_ad_policy.dart`
  (interstitial ad logic under the old AdMob stack) were deleted upstream with no LevelPlay
  equivalent added — the app currently only shows a bottom banner ad
  (`lib/app/ads/bottom_banner_ad.dart`).
