# Guide: Android TV / Google TV Remote Protocol

This document covers the platform distinction between Android TV and Google TV,
the remote control protocol they share, and how a future adapter would fit into
this project's architecture.

---

## Scope and naming — what this adapter is NOT

"Android TV" is an overloaded term. It refers to two separate things:

| Meaning | What it is |
|---|---|
| **Android TV (OS)** | Google's TV operating system — the software platform that some TVs and dongles run |
| **Android TV Remote Protocol** | A specific network protocol (ports 6466/6467, protobuf) exposed by the Android TV OS for remote control |

**This adapter is about the protocol, not the OS.**

Samsung (Tizen) and LG (webOS) are completely different operating systems with their own
proprietary remote protocols. They do not run Android TV, do not expose the Android TV
Remote Service, and have no relationship to this adapter. The `android_tv_adapter` is a
peer of `lg_adapter` and `samsung_adapter` — not a base class or parent.

```
TvBrandAdapter (abstract)
  ├── SamsungAdapter     ← Tizen WebSocket + JSON
  ├── LgAdapter          ← webOS WebSocket + JSON
  ├── HisenseAdapter     ← VIDAA protocol
  └── AndroidTvAdapter   ← Android TV Remote Protocol (protobuf, TCP TLS)  ← this guide
```

Hisense is the one overlapping case: some Hisense TVs run Android TV (and use
`AndroidTvAdapter`), others run VIDAA (and use `HisenseAdapter`). They are treated as
separate brands/protocols at pairing time.

---

## Platform distinction

| | Android TV | Google TV |
|---|---|---|
| Launched | 2014 | 2020 |
| What it is | The OS / platform (Android-based) | A UI shell / experience layer on top of Android TV |
| Relationship | The underlying OS | Superset — all Google TV devices run Android TV underneath |
| Typical hardware | Sony (older), Philips, TCL, Hisense (some), NVIDIA Shield | Chromecast with Google TV, Sony Bravia (2021+), TCL (newer) |

**Google TV is Android TV with a different launcher.** The remote control protocol is
the same at the OS level, so a single adapter covers both. The Chromecast with Google TV
is a Google TV device and requires no separate adapter.

---

## Remote control protocol

Android TV devices expose the **Android TV Remote Service** on the local network.
This is the same protocol used by Google's official Google TV Remote app (the one bundled
with Chromecast with Google TV and available on Android / iOS).

> **Terminology note:** Do not confuse this with **ANYMOTE**. ANYMOTE (port 9552) was
> the original pre-2014 Google TV protocol and is now obsolete. The current protocol is
> called **Android TV Remote Protocol v2** (service name `androidtvremote2`). They are
> different things.

### Protocol versions

| Version | When used | Notes |
|---|---|---|
| v1 | Android TV Remote Service < 5 | Older Android TV devices |
| v2 | Android TV Remote Service ≥ 5 | All current Google TV / Android TV devices |

You can check the service version on a TV at: *Settings → Apps → See all apps → Android TV Remote Service.*
A future adapter should detect or negotiate which version to use — this is the primary
split that would require a protocol variant in this project.

### Discovery

mDNS service type: `_androidtvremote2._tcp`

The device announces itself on the local network. Same discovery mechanism already used
for Samsung and LG (SSDP / mDNS scanning).

### Transport

| Property | Value |
|---|---|
| Transport | TCP with mutual TLS |
| Pairing port | `6467` |
| Remote control port | `6466` |
| Message format | Protocol Buffers (protobuf) |
| Pairing model | Certificate exchange (similar to LG TLS) |

Both sides generate self-signed certificates. During pairing the TV shows a PIN code
and the app exchanges its certificate — after that the client certificate is trusted
and reconnection is certificate-only (no PIN re-entry), analogous to Samsung's token
and LG's client-cert flow.

### Key codes

Commands are sent as **Android `KeyEvent` key codes** (integer constants). These are
defined by the Android OS, not by the manufacturer — so the same codes work across
Sony, TCL, Chromecast, and any other Android TV device. Standard remote buttons map
directly:

| Action | Android KeyEvent |
|---|---|
| D-pad Up | `KEYCODE_DPAD_UP` (19) |
| D-pad Down | `KEYCODE_DPAD_DOWN` (20) |
| D-pad Left | `KEYCODE_DPAD_LEFT` (21) |
| D-pad Right | `KEYCODE_DPAD_RIGHT` (22) |
| OK / Select | `KEYCODE_DPAD_CENTER` (23) |
| Back | `KEYCODE_BACK` (4) |
| Home | `KEYCODE_HOME` (3) |
| Volume Up | `KEYCODE_VOLUME_UP` (24) |
| Volume Down | `KEYCODE_VOLUME_DOWN` (25) |
| Mute | `KEYCODE_VOLUME_MUTE` (164) |
| Power | `KEYCODE_POWER` (26) |
| Channel Up | `KEYCODE_CHANNEL_UP` (166) |
| Channel Down | `KEYCODE_CHANNEL_DOWN` (167) |

The protobuf message wraps a key code and an action type (`KEY_DOWN` / `KEY_UP`).

### Text input

Text input is supported by sending individual key events for each character, or via
a dedicated `RemoteImeSendEvent` message in the protobuf schema that delivers a string
directly to the focused text field.

---

## Comparison with existing adapters

| Aspect | Samsung | LG | Android TV |
|---|---|---|---|
| Transport | WebSocket (TLS optional) | WebSocket (TLS) | Raw TCP (TLS) |
| Pairing | Token (TV approval prompt) | Client certificate + PIN | Certificate exchange + PIN |
| Message format | JSON | JSON | Protocol Buffers |
| Discovery | SSDP | SSDP | mDNS |
| Key codes | Brand string codes | HDMI-CEC / webOS codes | Android `KeyEvent` integers |

The structural pattern is the same: TLS transport with a one-time pairing ceremony that
produces a persisted credential (token / certificate), and then stateless command dispatch.
An `AndroidTvTransportClient` would implement the same `TransportClient` interface as the
Samsung and LG clients.

## Why one adapter covers Android TV, Google TV, and Chromecast

The protocol is implemented at the **Android TV OS level by Google** as the
"Android TV Remote Service" system app — not by the device manufacturer. Sony, TCL,
and Chromecast all ship the same OS service with the same ports, protobuf schema, and
key code set. Manufacturers do not customize the protocol.

The protocol variants system in this project handles the real differences:

| Difference | How to handle |
|---|---|
| v1 vs v2 protocol | Protocol variant (`default` = v2, `v1` for older service versions) |
| Power-key wake behavior | Device-level quirk; document in validation matrix, not in adapter |
| App shortcut keys (Netflix etc.) | Test per device; mark unsupported keys in `supportedCommands` |

**Devices that do NOT work with this protocol:**
- Amazon Fire TV — ships Android but does *not* include the Android TV Remote Service
- Hisense models not running stock Android TV (use the Hisense VIDAA adapter instead)

---

## Adapter architecture fit

A future adapter would follow the existing pattern:

```
lib/remote_control/data/adapters/
  android_tv_adapter.dart               ← TvBrandAdapter implementation
  android_tv/
    android_tv_key_mapper.dart          ← RemoteCommand → Android KeyEvent int
    android_tv_protocol_variants.dart   ← variant constants + predicates
    android_tv_transport_client.dart    ← abstract transport interface
    real_android_tv_transport_client.dart
    fake_android_tv_transport_client.dart
```

`TvBrand` would gain a new `androidTv` value. Because Google TV runs on Android TV,
no separate `googleTv` brand is needed — the same adapter handles both, potentially
with a protocol variant distinguishing them if behavioral differences are discovered.

---

## Open-source reference implementations

The protocol has been fully reverse-engineered. Existing implementations to use as
protocol references:

- **`androidtvremote2`** (Python) — The most actively maintained implementation.
  Used by Home Assistant's Android TV Remote integration. Contains the full `.proto`
  schema files for both pairing and control messages. Confirmed working across Sony,
  TCL, Philips, Chromecast with Google TV, and more.
  - GitHub: `tronikos/androidtvremote2`
  - PyPI: `androidtvremote2`

- **`AndroidTVRemoteControl`** (Swift / CocoaPods) — iOS/macOS implementation of
  the same v2 protocol. Useful reference for a Flutter Dart port since it is the
  closest in platform target.

- **`atvremote`** (Go) — `drosoCode/atvremote` on GitHub. Smaller but concise
  reference for the wire protocol.

The `.proto` schema files in `tronikos/androidtvremote2` (`remotemessage.proto`)
define the exact wire format for both the pairing handshake and the key event messages
and should be treated as the authoritative reference.

---

## ADB alternative (not recommended for production)

Android TV also exposes **ADB over TCP** on port `5555`, which allows sending key events
via `adb shell input keyevent <code>`. This works but requires the user to enable
developer mode on the TV — not a viable UX for a consumer app. Avoid this path.

---

## Implementation status

Per `references/product_specs.md` §6, Android TV / Google TV is a **Post-MVP expansion
candidate** with "High" protocol maturity. Re-prioritize when test hardware or a verified
external tester is available.

---

## Sources

Protocol details, port numbers, mDNS service type, and device compatibility in this
document were verified against the following sources (May 2026):

- [tronikos/androidtvremote2 — GitHub](https://github.com/tronikos/androidtvremote2) —
  Python implementation of the v2 protocol; authoritative `.proto` schema source
- [remotemessage.proto — tronikos/androidtvremote2](https://github.com/tronikos/androidtvremote2/blob/main/src/androidtvremote2/remotemessage.proto) —
  Protobuf schema for control messages
- [Android TV Remote — Home Assistant integration docs](https://www.home-assistant.io/integrations/androidtv_remote/) —
  Confirmed supported device list and v1/v2 version detection
- [Google TV (aka Android TV) Remote Control (v2) — protocol wiki](https://github.com/Aymkdn/assistant-freebox-cloud/wiki/Google-TV-(aka-Android-TV)-Remote-Control-(v2)) —
  Port numbers (6466/6467) and ANYMOTE vs v2 distinction
- [New Android TV Remote Service — XDA Forums](https://xdaforums.com/t/new-android-tv-remote-service.4355091/) —
  Community documentation of the remote service protocol
- [AndroidTVRemoteControl — CocoaPods](https://cocoapods.org/pods/AndroidTVRemoteControl) —
  Swift/iOS implementation reference
- [drosoCode/atvremote — GitHub](https://github.com/drosoCode/atvremote) —
  Go implementation reference
- [androidtvremote2 — PyPI](https://pypi.org/project/androidtvremote2/) —
  Release history confirming active maintenance
