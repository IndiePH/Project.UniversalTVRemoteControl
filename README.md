# one_remote

A new Flutter project.

## Current Runtime Modes

- Default app runtime uses real TV paths for quick physical-device testing:
  - Samsung command transport: real WebSocket transport
  - Device discovery: SSDP local-network discovery
- Optional fake Samsung transport can be enabled only when explicitly requested:
  - run with `--dart-define=USE_FAKE_SAMSUNG_TRANSPORT=true`
- Optional Samsung host override for local testing:
  - `--dart-define=SAMSUNG_TV_HOST=<tv-ip>`
- Samsung WebSocket trace (text input / pairing diagnosis; can be chatty):
  - `--dart-define=SAMSUNG_TRANSPORT_DEBUG=true`
  - In Android Studio / `adb logcat`, filter by tag **`samsung_transport`**

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
