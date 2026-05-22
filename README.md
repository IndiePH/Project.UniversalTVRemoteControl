# one_remote

Flutter app **OneRemote** (internal / working name: **Universal TV Remote** — use either label interchangeably in docs). See `references/product_specs.md` and `references/marketing_strategy.md` for naming detail.

## Current Runtime Modes

- Default app runtime uses real TV paths for quick physical-device testing:
  - Samsung command transport: real WebSocket transport
  - Hisense command transport: real VIDAA-style MQTT (TLS to TV port `36669`, self-signed cert allowed)
  - Device discovery: SSDP local-network discovery (on **Android**, the app acquires a Wi‑Fi **multicast lock** for the scan so SSDP replies are not filtered; `TV_HOST_OVERRIDE` still works if the TV does not advertise recognizable UPnP headers)
- Optional fake transport mode for all brand adapters (single switch):
  - run with `--dart-define=USE_FAKE_TRANSPORTS=true`
  - also switches discovery to fake scan data (includes a mock Hisense TV)
- In-app debug settings toggle (no rebuild required):
  - Remote screen top-right cog opens debug settings
  - `Use fake transports` switches discovery + Samsung/Hisense transport wiring at runtime
  - selection is persisted via `SharedPreferences` (`debug_use_fake_transports`)
  - if no saved override exists, compile-time `USE_FAKE_TRANSPORTS` remains the default
- Optional host override for all transports (single TV target):
  - `--dart-define=TV_HOST_OVERRIDE=<tv-ip>`
- Hisense MQTT topic client segment (must match what the TV expects after pairing; default `OneRemote`):
  - `--dart-define=HISENSE_MQTT_CLIENT_ID=<id>`
- Older Hisense / lab setups without TLS on port 36669:
  - `--dart-define=HISENSE_MQTT_PLAINTEXT=true`
- Hisense pairing code simulation (temporary dev behavior):
  - pairing requires a 4-digit code in both fake and real paths
  - accepted code is currently `1234`; incorrect codes show retry fallback
- Samsung WebSocket trace (text-input diagnosis) is ON by default:
  - set `--dart-define=SAMSUNG_TRANSPORT_DEBUG=false` to disable
  - In Android Studio / `adb logcat`, filter by tag **`samsung_transport`**
  - Logs are also written on-device to:
    - Android: `Android/data/<your.package>/files/one_remote_logs/`
- Optional Samsung text-input compatibility toggle:
  - `--dart-define=SAMSUNG_SEND_INPUT_END_PER_TEXT=true` (enables `SendInputEnd` after each text send)
- Samsung text-input capability exposure gate (keep disabled until physical validation):
  - default is OFF (Samsung device capability set excludes text input; adapter reports `supportsTextInput=false`)
  - enable only for validation runs with `--dart-define=SAMSUNG_ENABLE_TEXT_INPUT=true`
- In-app feedback webhook (default Apps Script URL in `FeedbackConfig`; optional overrides):
  - `--dart-define=FEEDBACK_WEBHOOK_URL=https://...`
  - `--dart-define=FEEDBACK_WEBHOOK_TOKEN=...`
  - Operator setup: `references/feedback-collection-setup.md`

## CI and local quality checks

GitHub Actions workflow [`.github/workflows/flutter_ci.yml`](.github/workflows/flutter_ci.yml) runs on pushes and pull requests to `main`, `master`, and `develop`:

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
| Android Gradle | `buildTypes.debug` (default) | `buildTypes.release` (debug signing placeholder until release keystore) |
| iOS Xcode | Debug configuration | Release configuration |

**Not implemented yet (by design):**

- Gradle **product flavors** (e.g. `dev` / `staging` / `prod`) - configuration uses `--dart-define` and in-app debug toggles instead; see **Current Runtime Modes** above.
- `AppEnvironment.development` - enum value reserved; `AppBuildConfig.developmentFlavorReserved` documents the hook until a flavor or dart-define wires it.
- **Profile** builds (`flutter run --profile`) use production DI today; profile-specific hooks can attach to `AppBuildProfile.profile` in `lib/app/configurations/app_build_config.dart`.

Lint rules: `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
