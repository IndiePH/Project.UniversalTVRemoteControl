# Guide: Android TV / Google TV Remote Protocol

This document covers the platform distinction between Android TV and Google TV,
the remote control protocol they share, and how the adapter fits into this
project's architecture.

**Status: implemented.** `AndroidTvAdapter` and `TclGoogleTvAdapter` both ship today
(`references/product_specs.md` §6/§implementation — "Adapter shipped... experimental
support tier"). The sections below describe the current, real implementation, not a
future one.

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

The protobuf message (`RemoteKeyInject`) wraps a `key_code` and a `RemoteDirection`:

```
UNKNOWN_DIRECTION = 0
START_LONG        = 1   ← start of long press
END_LONG          = 2   ← end of long press
SHORT             = 3   ← normal tap/press — used for every standard button send
```

### App launch (Netflix, YouTube, Prime Video, Disney+, ...)

Sent as `RemoteAppLinkLaunchRequest` (field 90 on `RemoteMessage`), carrying a single
`app_link` string. The TV resolves this via `Intent.parseUri()`, so it must be a URI the
target app registers a native intent filter for. `AndroidTvKeyMapper` uses `https://`
App Links (e.g. `https://www.netflix.com`) — see `android_tv_key_mapper.dart`. The
legacy `market://launch?id=<packageName>` scheme (an undocumented Play Store intent)
is no longer reliable on current Android TV/Google TV builds; it's kept only as a
`VariantKeyMap` override on `TclGoogleTvAdapter` until verified against the `https://`
alternative on real TCL hardware.

### Text input

Text input is supported by sending individual key events for each character, or via
the `RemoteImeBatchEdit` message in the protobuf schema, which delivers a string
directly to the focused text field. The required sub-fields (`RemoteEditInfo`,
`RemoteImeObject`, counters) are non-obvious — cross-check against the Python
`send_text_command` implementation in `tronikos/androidtvremote2` before changing
`sendText` in `android_tv_tcp_transport_client.dart`.

### Pairing handshake

All pairing messages wrap in `OuterMessage` (`polo.proto`), exchanged over port 6467:

1. Client sends `OuterMessage { pairing_request { service_name, client_name } }`
2. TV sends `OuterMessage { pairing_request_ack { server_name } }` — TV now shows a PIN
3. Client sends `OuterMessage { options { input_encodings, output_encodings } }`
4. TV sends `OuterMessage { configuration { encoding, client_role } }`
5. Client sends `OuterMessage { configuration_ack }` (empty)
6. Client sends `OuterMessage { secret { secret: <computed_bytes> } }`
7. TV sends `OuterMessage { secret_ack { secret: <echo> } }` — pairing success

Each message is preceded by a 4-byte big-endian length prefix on the wire (confirmed
against the Python `connection.py` reference).

**Pairing code format:** 6 hex characters (e.g. `"F3A2C1"`), not a 4-digit decimal PIN.
Characters 0–1 are a verification/checksum byte; characters 2–5 feed the secret formula.

**Secret formula** (from the Python source, exact):

```python
h = hashlib.sha256()
h.update(bytes.fromhex(f"{client_modulus:X}"))
h.update(bytes.fromhex(f"0{client_exponent:X}"))
h.update(bytes.fromhex(f"{server_modulus:X}"))
h.update(bytes.fromhex(f"0{server_exponent:X}"))
h.update(bytes.fromhex(pairing_code[2:]))  # last 4 hex chars only
secret_bytes = h.digest()
```

Verify: `secret_bytes[0] == int(pairing_code[0:2], 16)`. The four `modulus`/`exponent`
values are the RSA key components from the client's and server's certificates — not
the full DER-encoded public key.

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

```
lib/remote_control/data/adapters/
  android_tv_adapter.dart                 ← TvBrandAdapter implementation (TvBrand.androidTv)
  tcl_google_tv_adapter.dart               ← TvBrandAdapter implementation (TvBrand.tcl,
                                              protocolVariant googleTv) — reuses AndroidTvKeyMapper
                                              via VariantKeyMap for its app-launch overrides
  android_tv/
    android_tv_key_mapper.dart            ← RemoteCommand → CommandPayload (KeySequence/AppLink)
    android_tv_protocol_variants.dart     ← variant constants + predicates
    android_tv_transport_client.dart      ← abstract transport interface
    android_tv_tcp_transport_client.dart  ← real transport (protobuf/TLS)
    android_tv_certificate_store.dart     ← RSA keypair + self-signed cert persistence
    android_tv_remote_messages.dart       ← hand-written protobuf message classes
    android_tv_pairing_messages.dart      ← hand-written pairing (polo.proto) message classes
  debug/
    fake_android_tv_transport_client.dart
```

`TvBrand.androidTv` covers Android TV. Because Google TV runs on Android TV, it does not
get its own `TvBrand` value — `TclGoogleTvAdapter` instead reports `TvBrand.tcl` with a
distinct `protocolVariant`, since TCL also ships a non-Google-TV line under the same
brand. Any other Google TV device (e.g. a Sony Bravia) would use `AndroidTvAdapter`
directly rather than needing a brand-specific subclass.

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

Shipped — `AndroidTvAdapter` and `TclGoogleTvAdapter` are both live, listed in
`references/product_specs.md` §6 as "Adapter shipped... experimental support tier."

`AndroidTvKeyMapper`'s `https://` App Link URIs (`android_tv_key_mapper.dart`) are
hardware-confirmed working on real hardware for Prime Video, Disney+, and YouTube.
Netflix required a path segment — the bare `https://www.netflix.com` domain falls
through to a browser instead of the app; `https://www.netflix.com/title` resolves
correctly. Still open: whether `TclGoogleTvAdapter`'s legacy `market://`
`VariantKeyMap` override (kept for TCL hardware not yet tested against the `https://`
links) can be dropped once TCL is verified.

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
