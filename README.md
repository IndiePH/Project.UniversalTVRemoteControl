# one_remote

Flutter app **OneRemote** (internal / working name: **Universal TV Remote** — use either label interchangeably in docs). Control smart TVs over Wi‑Fi from Android or iOS.

**Version:** `1.4.1+19` (see `pubspec.yaml`)

## Overview

OneRemote discovers TVs on the local network, pairs with brand-specific protocols, and provides a customizable remote control surface. Store-listed Wi‑Fi brands: **Samsung, LG, Hisense, and Chromecast with Google TV**. Other adapters (Roku, TCL, etc.) remain experimental until validated.

**Product docs:** `references/product_specs.md` · **Implementation status:** `references/implementation_tasks.md` · **Store checklist:** `references/compliance-and-release-requirements.md` · **Persistent TV identity:** `references/goals/goal-persistent-device-identity.md`

### Supported brands (Wi‑Fi)

| Brand | Status | Notes |
| --- | --- | --- |
| Samsung (Tizen) | Primary validation target | WebSocket transport; TV-side approval + token auth |
| LG (webOS) | Active development | SSAP WebSocket; in-app text input pending transport |
| Hisense (VIDAA) | Active development | MQTT TLS (port `36669`); PIN pairing |
| Chromecast with Google TV (Android TV) | Store-listed (experimental tier) | Android TV Remote Protocol v2; not Cast-only dongles |
| Roku / TCL legacy Wi‑Fi | Experimental | See `references/tcl_validation_matrix.md`; not in store listing |

Physical validation runbooks: `references/samsung_validation_matrix.md`, `references/hisense_validation_matrix.md`.

## Project structure

```
lib/
  app/                 # Shell, DI bootstrap, ads, monetization, compliance, feedback, diagnostics
  remote_control/
    presentation/      # Remote home, pairing, layout editor, shared widgets
    application/       # Command routing, discovery, connection state, device policies
    domain/            # TvDevice, RemoteCommand, capabilities, contracts
    data/              # Brand adapters, SSDP discovery, transport clients
    debug/             # Fake transports for offline / lab runs
  theme/               # AppTheme, AppColors
  l10n/                # Localization
functions/             # Firebase callable — Android Pro receipt validation
test/                  # Unit and widget tests
references/            # Specs, compliance, validation matrices, guides
```

Architecture follows presentation → application → domain → data. Brand behavior lives in per-brand adapter + transport trees under `lib/remote_control/data/adapters/`.

## Getting started (developers)

**Prerequisites:** Flutter SDK compatible with `pubspec.yaml` (`sdk: ^3.12.0`), Android SDK and/or Xcode for device builds.

```bash
flutter pub get
flutter run
```

Default wiring uses **real** Samsung, LG, and Hisense transports for physical-TV testing. Use fake transports only for offline work — see **Current Runtime Modes** below.

On a phone and TV on the same LAN: open the app → pair (scan or manual IP) → remote home. Debug settings (remote screen cog) expose fake-transport toggle, diagnostics, and transport log copy.

## Current Runtime Modes

- Default app runtime uses real TV paths for quick physical-device testing:
  - Samsung command transport: real WebSocket transport
  - LG command transport: real webOS SSAP WebSocket transport
  - Hisense command transport: real VIDAA-style MQTT (TLS to TV port `36669`, self-signed cert allowed)
  - Device discovery: SSDP local-network discovery (on **Android**, the app acquires a Wi‑Fi **multicast lock** for the scan so SSDP replies are not filtered; `TV_HOST_OVERRIDE` still works if the TV does not advertise recognizable UPnP headers)
- Connection behavior (active device on remote home):
  - Live transport state via `TvConnectionStateService`; `connect()` runs on subscribe and on a **5 s** periodic reconnect when `disconnected` or `error` (paused while another route covers home, e.g. pairing; also paused in background)
  - TV **Deny** / revoked remote-control authorization is `ConnectionState.unauthorized` — status **Allow this remote on your TV**; **no** 5 s retry (use the pair button to request Allow again). This is not reported as a Crashlytics crash.
  - Pairing / saved-device rows use `TvReachabilityService` TCP reachability probes
  - Pairing credentials persist across restarts (`flutter_secure_storage`); preferred key is the proven per-TV stable id, with legacy host-keyed fallback during migration
  - After a router/DHCP IP change, rediscovery updates the saved TV's mutable `host` so reconnect does not require re-pairing when stable identity is known
- Optional fake transport mode for all brand adapters (single switch):
  - run with `--dart-define=USE_FAKE_TRANSPORTS=true`
  - also switches discovery to fake scan data (includes a mock Hisense TV)
- In-app debug settings toggle (no rebuild required):
  - Remote screen top-right cog opens debug settings
  - `Use fake transports` switches discovery + Samsung/LG/Hisense transport wiring at runtime
  - selection is persisted via `SharedPreferences` (`debug_use_fake_transports`)
  - if no saved override exists, compile-time `USE_FAKE_TRANSPORTS` remains the default
- Optional host override for all transports (single TV target):
  - `--dart-define=TV_HOST_OVERRIDE=<tv-ip>`
- Hisense MQTT topic client segment (must match what the TV expects after pairing; default `OneRemote`):
  - `--dart-define=HISENSE_MQTT_CLIENT_ID=<id>`
- Older Hisense / lab setups without TLS on port 36669:
  - `--dart-define=HISENSE_MQTT_PLAINTEXT=true`
- Hisense pairing: real transport forwards the TV-shown 4-digit PIN; fake transport accepts dev PIN `1234` for offline runs
- Samsung WebSocket trace (text-input diagnosis) is ON by default:
  - set `--dart-define=SAMSUNG_TRANSPORT_DEBUG=false` to disable
  - In Android Studio / `adb logcat`, filter by tag **`samsung_transport`**
  - Logs are also written on-device to:
    - Android: `Android/data/<your.package>/files/one_remote_logs/`
- Optional Samsung text-input compatibility toggles:
  - `--dart-define=SAMSUNG_SEND_INPUT_END_PER_TEXT=true` (enables `SendInputEnd` after each text send)
  - `--dart-define=SAMSUNG_ENABLE_TEXT_INPUT=true` (exposes text input capability — default OFF until physical validation)
- TCL legacy Wi‑Fi experimental gate:
  - `--dart-define=TCL_LEGACY_WIFI_ENABLED=true`
- Monetization / compliance overrides:
  - `--dart-define=PRO_PRODUCT_ID=<sku>` (default catalog in `lib/app/configurations/app_monetization_di_config.dart`)
  - `--dart-define=ADMOB_BANNER_ANDROID=<id>` / `ADMOB_BANNER_IOS=<id>` (test IDs used when Remote Config `test_ads_enabled` or debug)
  - `--dart-define=PRIVACY_POLICY_URL=https://...`
- In-app feedback webhook (default Apps Script URL in `FeedbackConfig`; optional overrides):
  - `--dart-define=FEEDBACK_WEBHOOK_URL=https://...`
  - `--dart-define=FEEDBACK_WEBHOOK_TOKEN=...`
  - Operator setup: `references/feedback-collection-setup.md`

Brand-specific flag templates are also copyable from the in-app debug sheet (`RuntimeFlagsTemplateDebug`).

## CI and local quality checks

GitHub Actions workflow [`.github/workflows/flutter_ci.yml`](.github/workflows/flutter_ci.yml) runs on pushes and pull requests to `main`, `master`, and `develop`. CI is **skipped** when the commit/PR diff touches **only** paths under `references/` (any commit subject, e.g. `docs(references): …` or `chore: tweak docs in references`). If `lib/`, `test/`, or any path outside `references/` changes, CI runs.

1. `dart format --output=none --set-exit-if-changed .` - fails when formatting drifts
2. `flutter analyze --fatal-infos` - static analysis / lints
3. `flutter test` - unit and widget tests

Reproduce locally:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

## Build profiles and flavors (intentional gaps)

| Layer | Debug | Release / store |
| --- | --- | --- |
| Flutter build mode | `kDebugMode` (default `flutter run`) | `kReleaseMode` (`flutter build apk --release`, etc.) |
| App DI environment | `AppEnvironment.debug` via `AppBuildConfig.environmentForMain()` | `AppEnvironment.production` |
| Android Gradle | `buildTypes.debug` (default) | `buildTypes.release` signed via `android/key.properties` (release Gradle tasks fail explicitly if missing; debug builds unaffected) |
| iOS Xcode | Debug configuration | Release configuration |

**Not implemented yet (by design):**

- Gradle **product flavors** (e.g. `dev` / `staging` / `prod`) - configuration uses `--dart-define` and in-app debug toggles instead; see **Current Runtime Modes** above.
- `AppEnvironment.development` - enum value reserved; `AppBuildConfig.developmentFlavorReserved` documents the hook until a flavor or dart-define wires it.
- **Profile** builds (`flutter run --profile`) use production DI today; profile-specific hooks can attach to `AppBuildProfile.profile` in `lib/app/configurations/app_build_config.dart`.

### Building APKs for local testing

**Debug APK** — no signing required, suitable for sideloading and device testing:

```
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

**Release APK** — requires `android/key.properties`:

```
flutter build apk --release
```

`android/key.properties` is gitignored. Create it before running a release build:

```
storePassword=<your-password>
keyPassword=<your-key-password>
keyAlias=<your-alias>
storeFile=<path-to-your.jks>
```

When `key.properties` is present, `signingConfigs.release` is applied to the release build type. When it is absent, the signing config is skipped and `gradle.taskGraph.whenReady` throws an explicit error if `assembleRelease` or `bundleRelease` is in the task graph — debug builds are unaffected.

**Android / Kotlin incremental (cross-drive):** `android/gradle.properties` sets `kotlin.incremental=false` to avoid Kotlin incremental cache failures when the Flutter project and Pub cache live on different drives (for example project on `E:` and Pub cache on `C:`). Re-enable only if both trees share a drive and incremental builds are reliable again.

Lint rules: `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`.

## Firebase (Pro validation)

Android Pro IAP receipt validation uses a Firebase callable in `functions/`. Deploy and operator setup: `references/goals/goal-pro-receipt-validation-remote-setup.md`.

## Documentation index

| Document | Purpose |
| --- | --- |
| `references/product_specs.md` | Product source of truth — features, UX, architecture |
| `references/implementation_tasks.md` | Living implementation plan and status tracker |
| `references/changelog.md` | Dated implementation / direction updates |
| `references/goals/goal-persistent-device-identity.md` | Stable TV identity across IP changes (branch goal) |
| `references/persistent-device-identity.md` | Per-brand identity sources, migration, reconciliation |
| `references/compliance-and-release-requirements.md` | Store submission checklist |
| `references/marketing_strategy.md` | Naming, positioning, ad strategy |
| `references/guide-adding-protocol-variant.md` | How to add a new protocol variant |
| `references/guide-android-tv-remote-protocol.md` | Android TV protocol notes |
| `references/feedback-collection-setup.md` | In-app feedback webhook setup |
| `references/third_party_licenses.md` | OSS and manufacturer API license audit |
| `references/samsung_validation_matrix.md` | Samsung physical validation runbook |
| `references/hisense_validation_matrix.md` | Hisense physical validation runbook |
| `references/tcl_validation_matrix.md` | TCL experimental validation runbook |
