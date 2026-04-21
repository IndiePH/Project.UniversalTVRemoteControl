# Goal: Implement LG webOS Remote Control in OneRemote

**Goal ID:** `lg-remote`
**Created:** 2026-04-21
**Status:** `pending`
**Owner:** wlvyr

---

## Goal Statement

Implement a fully wired LG webOS remote control transport layer in OneRemote, following the
existing Strategy + transport-injection pattern already established for Samsung and Hisense.
The result is an `LgAdapter` backed by a real `RealLgTransportClient` that can discover,
pair, send commands, and (after physical validation) send text input to LG webOS TVs over
the local network.

---

## Architecture Context

The codebase uses two nested layers. Both layers already exist for Samsung and Hisense.
LG has only the adapter skeleton — no transport layer.

```
BrandRoutedRemoteCommandService   ← selects adapter by TvBrand at runtime
  └─ TvBrandAdapter (interface)   ← unified command contract
       ├─ SamsungAdapter           ← backed by SamsungTransportClient (complete)
       ├─ HisenseAdapter           ← backed by HisenseTransportClient (complete)
       └─ LgAdapter                ← EXISTS as stub; sendCommand() only logs; no transport
```

`LgAdapter` is the adapter that bridges app commands → LG webOS protocol.
`LgTransportClient` + `RealLgTransportClient` is the missing transport that speaks webOS
WebSocket SSAP. The goal is to fill that gap following the established pattern.

### Relevant existing files

| File | Role |
|---|---|
| `application/tv_brand_adapter.dart` | Unified adapter interface |
| `data/adapters/lg_adapter.dart` | Adapter skeleton (stub) |
| `data/adapters/samsung_adapter.dart` | Reference: adapter wiring |
| `data/adapters/samsung/samsung_transport_client.dart` | Reference: transport interface |
| `data/adapters/samsung/real_samsung_transport_client.dart` | Reference: real WebSocket transport |
| `data/adapters/samsung/fake_samsung_transport_client.dart` | Reference: test fake |
| `data/adapters/samsung/real_samsung_pairing_token_store.dart` | Reference: key persistence |
| `data/adapters/samsung/samsung_tls_trust_store.dart` | Reference: self-signed TLS trust |
| `data/adapters/transport_event_emitter_mixin.dart` | Reusable broadcast emitter |
| `data/adapters/adapter_device_info_log_gate.dart` | Reusable per-device log gate |
| `data/adapters/command_key_map.dart` | Base class for key mappers |
| `domain/models/tv_brand_capabilities.dart` | Brand capability defaults |
| `test/samsung_test_lane_test.dart` | Reference: test lane structure |

---

## Verified LG webOS Protocol Reference

Sourced from: Home Assistant `aiowebostv`, `lgtv2` (Node.js), `LGwebOSTVRC`, official LG
webOS developer docs (webostv.developer.lge.com), and `flutter-remote` (Dart reference impl).

### Transport

| Property | Value |
|---|---|
| Primary endpoint | `wss://host:3001` (TLS, self-signed cert) |
| Fallback endpoint | `ws://host:3000` (plaintext — blocked on firmware from Jan 2023+) |
| TLS cert | Self-signed — bypass via `HttpClient.badCertificateCallback` (same pattern as `SamsungTlsTrustStore`) |
| Dart compatibility | `dart:io` WebSocket — exact same primitives as Samsung; no new dependencies needed |

### Handshake — first-time pairing (no client key)

```json
{
  "type": "register",
  "id": "register_0",
  "payload": {
    "forcePairing": false,
    "pairingType": "PROMPT",
    "manifest": {
      "manifestVersion": 1,
      "appVersion": "1.1",
      "signed": {
        "created": "20140509",
        "appId": "com.lge.test",
        "vendorId": "com.lge",
        "localizedAppNames": { "": "LG Remote App" },
        "localizedVendorNames": { "": "LG Electronics" },
        "permissions": [
          "TEST_SECURE", "CONTROL_INPUT_TEXT", "CONTROL_MOUSE_AND_KEYBOARD",
          "READ_INSTALLED_APPS", "READ_LGE_SDX", "READ_NOTIFICATIONS", "SEARCH",
          "WRITE_SETTINGS", "WRITE_NOTIFICATION_ALERT", "CONTROL_POWER",
          "READ_CURRENT_CHANNEL", "READ_RUNNING_APPS", "READ_UPDATE_INFO",
          "UPDATE_FROM_REMOTE_APP", "READ_LGE_TV_INPUT_EVENTS", "READ_TV_CURRENT_TIME"
        ],
        "serial": "2f930e2d2cfe083771f68e4fe7bb07"
      },
      "permissions": [
        "LAUNCH", "LAUNCH_WEBAPP", "APP_TO_APP", "CLOSE", "TEST_OPEN",
        "TEST_PROTECTED", "CONTROL_AUDIO", "CONTROL_DISPLAY",
        "CONTROL_INPUT_MEDIA_RECORDING", "CONTROL_POWER", "CONTROL_INPUT_JOYSTICK",
        "CONTROL_INPUT_KEYBOARD", "CONTROL_INPUT_MOUSE", "CONTROL_INPUT_TEXT",
        "READ_APP_INFO", "READ_CURRENT_CHANNEL", "READ_INPUT_DEVICE_LIST",
        "READ_INPUT_DEVICE_STATUS", "READ_RUNNING_APPS", "READ_TV_CHANNEL_LIST",
        "WRITE_NOTIFICATION_ALERT", "CREATE_TOAST_NOTIFICATION"
      ]
    }
  }
}
```

> **Critical:** Fewer than ~39 permissions results in a "401 insufficient permissions" error.
> The `serial` field is an RSA-SHA256 signature from the official LG remote app — do not change it.

TV response on user approval (shown on-screen prompt, ~15s window):

```json
{
  "type": "response",
  "id": "register_0",
  "payload": { "client-key": "UNIQUE_CLIENT_KEY", "returnValue": true }
}
```

### Handshake — reconnection with stored client key

Same register message, add `"client-key": storedKey` to the payload. No TV prompt shown.

```json
{
  "type": "register",
  "id": "register_0",
  "payload": {
    "forcePairing": false,
    "pairingType": "PROMPT",
    "client-key": "STORED_CLIENT_KEY",
    "manifest": { ... }
  }
}
```

Successful reconnect response (no new key in payload):

```json
{ "type": "response", "id": "register_0", "payload": { "returnValue": true } }
```

Stale/rejected key response: `returnValue: false` — clear stored key and re-pair.

### SSAP command format

```json
{
  "type": "request",
  "id": "UNIQUE_ID",
  "uri": "ssap://service/method",
  "payload": {}
}
```

Response: `{ "type": "response", "id": "UNIQUE_ID", "payload": { "returnValue": true } }`
Error:    `{ "type": "response", "id": "UNIQUE_ID", "payload": { "returnValue": false, "errorCode": -1, "errorText": "..." } }`

### Verified SSAP command map

| `RemoteCommand` | SSAP URI | Payload | Notes |
|---|---|---|---|
| `power` | `ssap://system/turnOff` | `{}` | Power off only; power on requires WoL |
| `volumeUp` | `ssap://audio/volume/up` | `{}` | |
| `volumeDown` | `ssap://audio/volume/down` | `{}` | |
| `mute` | `ssap://audio/setMute` | `{"mute": <bool>}` | Requires knowing current state; call `ssap://audio/getStatus` first or track in memory |
| `channelUp` | `ssap://tv/channelUp` | `{}` | |
| `channelDown` | `ssap://tv/channelDown` | `{}` | |
| `home` | `ssap://system.launcher/home` | `{}` | |
| `back` | Pointer input socket | `type:button\nbutton:back\ndown:1\n\n` | See pointer socket section |
| `dpadUp/Down/Left/Right/Ok` | Pointer input socket | `type:button\nbutton:<dir>\ndown:1\n\n` | See pointer socket section |
| `netflix` | `ssap://com.webos.appmanager/launch` | `{"id": "netflix"}` | |
| `primeVideo` | `ssap://com.webos.appmanager/launch` | `{"id": "amazon"}` | |
| `disneyPlus` | `ssap://com.webos.appmanager/launch` | `{"id": "disneyplus"}` | |
| `web` | `ssap://com.webos.appmanager/launch` | `{"id": "com.webos.app.browser"}` | |
| `input` | `ssap://tv/switchInput` | `{"inputId": "..."}` | Requires available input list |
| `menu` | `ssap://com.webos.service.tv.display/setCurrentPictureMode` | — | Not a standard key; consider unsupported |

### Pointer input socket (dpad, back, navigation)

Obtain socket URL first:
```json
{ "type": "request", "id": "ptr_0", "uri": "ssap://com.webos.service.networkinput/getPointerInputSocket", "payload": {} }
```

Response: `{ "payload": { "socketPath": "wss://host:3001/netinput.pointer.sock" } }`

Then connect to `socketPath` and send **newline-delimited key-value pairs** (not JSON):
```
type:button
button:up
down:1

```
(blank line terminates the message; send a matching `down:0` message to release)

Button values: `up`, `down`, `left`, `right`, `ok`, `back`, `home`

### IME / text input

| Operation | URI | Payload |
|---|---|---|
| Insert text | `ssap://com.webos.service.ime/insertText` | `{"text": "hello", "replace": 0}` |
| Delete chars | `ssap://com.webos.service.ime/deleteCharacters` | `{"count": 1}` |
| Send enter | `ssap://com.webos.service.ime/sendEnterKey` | `{}` |

`replace: 0` = insert at cursor; `replace: 1` = replace entire field content.
IME only available when a text field is focused on the TV.

### webOS version differences

| Version | Port | TLS required | Notes |
|---|---|---|---|
| webOS 3–5 | 3000 | No | `ws://` accepted; broad SSAP support |
| webOS 6 | 3000 or 3001 | Optional | Both ports, standard SSAP |
| webOS 22–24 (2022+) | 3001 | **Yes** | `ws://3000` blocked on newer firmware |

Implementation must try `wss://host:3001` first, fall back to `ws://host:3000`.

### Client key storage

Use `SharedPreferences` (matches project pattern: `RealSamsungPairingTokenStore`,
`SharedPrefsLayoutRepository`). Key: `lg_client_key_<host>`. No new packages required.

---

## Task Decomposition

### SG-1 · LG Protocol Adapter & Transport Layer

> Foundation. All other sub-goals depend on this. No external deps.

---

#### T-1.1 · Define `LgTransportClient` abstract interface

- **File:** `data/adapters/lg/lg_transport_client.dart`
- **Objective:** Interface declares `connect`, `requestClientKey`, `sendKey`, `sendText`, `watchRegistrationState`, `disconnect`; both `RealLgTransportClient` and `FakeLgTransportClient` implement it and compile; follows shape of `SamsungTransportClient`
- **Testable done:** `flutter analyze` passes with both implementations declared
- **Deps:** none
- **Risk:** LOW
- **Skills:** `abstraction-domain-modeling`, `api-design`
- **Status:** `pending`

---

#### T-1.2 · Implement `RealLgTransportClient`

- **File:** `data/adapters/lg/real_lg_transport_client.dart`
- **Objective:**
  - Connects to `wss://host:3001` (fallback `ws://host:3000`) using `dart:io` WebSocket
  - Sends 39-permission registration manifest on connect
  - Receives `client-key` from TV pairing response and exposes it via callback/completer
  - Sends SSAP `{type: "request", ...}` JSON and parses `{returnValue: bool}` response
  - Manages a single open WebSocket per `deviceId` (reconnect if dropped)
  - Reuses `SamsungTlsTrustStore` pattern for self-signed TLS cert bypass
  - Emits `TransportEvent` via `TransportEventEmitterMixin` (reuse existing mixin)
  - Constructor: `RealLgTransportClient({required String Function(String) hostResolver})`
- **Testable done:** `connect()` completes without error against a mock/fake TV socket; `sendKey()` with a known SSAP URI produces correct JSON on the wire
- **Deps:** T-1.1
- **Risk:** MEDIUM — real TLS/network I/O; self-signed cert handling needed
- **Skills:** `language-specific-implementation`, `error-handling-resilience`
- **Implementation note:** Pointer input socket (`wss://host:3001/netinput.pointer.sock`) must also be managed for dpad/back commands — connect on first pointer command, cache per deviceId
- **Status:** `pending`

---

#### T-1.3 · Implement `FakeLgTransportClient`

- **File:** `data/adapters/lg/fake_lg_transport_client.dart`
- **Objective:** All interface methods complete without throwing; `watchRegistrationState` emits `connected`; compatible with test injection; mirrors `FakeSamsungTransportClient` structure; emits `TransportEvent` via mixin
- **Testable done:** `LgAdapter(transportClient: FakeLgTransportClient())` passes `flutter test`
- **Deps:** T-1.1
- **Risk:** LOW
- **Skills:** `test-creation-strategy`
- **Status:** `pending`

---

#### T-1.4 · Implement `LgKeyMapper` with SSAP command map

- **File:** `data/adapters/lg/lg_key_mapper.dart`
- **Objective:** Replaces `_LgCommandKeyMap` (which incorrectly returns `command.name`); maps all `kCommonSupportedRemoteCommands` to verified SSAP URIs; commands routed via pointer socket (dpad, back) return a sentinel value (e.g. `"POINTER:up"`) that `RealLgTransportClient` intercepts to use the pointer socket path
- **Testable done:** `LgKeyMapper().primaryKeyCodeFor(RemoteCommand.volumeUp)` returns `"ssap://audio/volume/up"`; no command in `kCommonSupportedRemoteCommands` returns `null`
- **Deps:** none
- **Risk:** LOW
- **Skills:** `refactoring`, `clean-code-solid`
- **SSAP map to implement:** See "Verified SSAP command map" table above
- **Status:** `pending`

---

#### T-1.5 · Wire `LgAdapter` to inject `LgTransportClient`

- **File:** `data/adapters/lg_adapter.dart` (update existing)
- **Objective:** Constructor `LgAdapter({LgTransportClient? transportClient, CommandKeyMap? keyMap})`; `sendCommand()` calls `_transportClient.sendKey()`; `preparePairing()` calls `_transportClient.requestClientKey()`; `sendText()` calls `_transportClient.sendText()`; `watchRemoteTextInputReady()` delegates to transport; `flutter analyze` passes
- **Testable done:** `LgAdapter(transportClient: FakeLgTransportClient()).sendCommand(device, RemoteCommand.volumeUp)` completes without error
- **Deps:** T-1.1, T-1.2, T-1.3, T-1.4
- **Risk:** LOW
- **Skills:** `refactoring`
- **Status:** `pending`

---

#### T-1.6 · Add `LgAdapter` to `OneRemoteApp._buildLgAdapter()`

- **File:** `app/one_remote_app.dart` (update existing)
- **Objective:** `_buildLgAdapter()` returns `LgAdapter(transportClient: RealLgTransportClient(hostResolver: _resolveLgHost))` in production path and `LgAdapter()` in fake path; `_resolveLgHost` follows same IPv4 extraction pattern as `_resolveSamsungHost`; `flutter analyze` passes
- **Testable done:** App compiles and `flutter analyze` passes; debug sheet reflects LG transport state
- **Deps:** T-1.5
- **Risk:** LOW
- **Skills:** `clean-code-solid`
- **Status:** `pending`

---

### SG-2 · LG Pairing Verification Wiring

> Requires SG-1 complete.

---

#### T-2.1 · Implement `RealLgPairingKeyStore`

- **File:** `data/adapters/lg/real_lg_pairing_key_store.dart`
- **Objective:** `storeKeyForHost(host, key)` persists via `SharedPreferences` with key `lg_client_key_<host>`; `keyForHost(host)` retrieves across cold starts; `clearKeyForHost(host)` removes; mirrors `RealSamsungPairingTokenStore`
- **Testable done:** Store → cold restart → retrieve returns same key; clear → retrieve returns null
- **Deps:** T-1.2
- **Risk:** LOW
- **Skills:** `error-handling-resilience`
- **Status:** `pending`

---

#### T-2.2 · Wire `preparePairing()` — first-time client-key acquisition

- **File:** `data/adapters/lg/real_lg_transport_client.dart` + `data/adapters/lg_adapter.dart`
- **Objective:** `LgAdapter.preparePairing(device: ...)` triggers `requestClientKey()`; TV shows authorization prompt; accepted response stores the client-key via `RealLgPairingKeyStore`; timeout after ~20s surfaces as `LgPairingTimeoutException`; rejection surfaces as `LgPairingRejectedException`; both are caught by `BrandRoutedRemoteCommandService` and returned as `CommandDispatchResult.failure`
- **Testable done:** `preparePairing` completes when fake transport simulates key response; timeout exception surfaces correctly
- **Deps:** T-2.1
- **Risk:** MEDIUM — async TV-side timeout; rejection path must be handled
- **Skills:** `error-handling-resilience`, `abstraction-domain-modeling`
- **Status:** `pending`

---

#### T-2.3 · Wire reconnection with stored client key

- **File:** `data/adapters/lg/real_lg_transport_client.dart`
- **Objective:** `connect()` checks `RealLgPairingKeyStore` for stored key; if present, includes `"client-key"` in register payload; no TV prompt on success; stale/rejected key (`returnValue: false`) clears store and throws `LgPairingSessionExpiredException` so caller can trigger re-pair
- **Testable done:** Second `connect()` call with stored key completes without re-prompting; stale key clears store and throws
- **Deps:** T-2.2
- **Risk:** MEDIUM — session state correctness
- **Skills:** `error-handling-resilience`
- **Status:** `pending`

---

### SG-3 · LG Text-Input / IME Transport

> Requires SG-2 complete. `supportsTextInput` stays `false` until T-5.2 physical validation.

---

#### T-3.1 · Implement `sendText()` via SSAP IME

- **File:** `data/adapters/lg/real_lg_transport_client.dart`
- **Objective:** Sends `{type: "request", uri: "ssap://com.webos.service.ime/insertText", payload: {text: text, replace: 0}}`; `returnValue: false` surfaces as `TextInputCompatibilityException` (existing type in `application/text_input_compatibility_exception.dart`)
- **Testable done:** `sendText(deviceId: ..., text: "hello")` produces correct JSON; error response produces correct exception type
- **Deps:** T-2.3
- **Risk:** MEDIUM — IME only available when text field is focused on TV
- **Skills:** `error-handling-resilience`
- **Status:** `pending`

---

#### T-3.2 · Implement `watchRemoteTextInputReady()` stream

- **File:** `data/adapters/lg/real_lg_transport_client.dart` + `data/adapters/lg_adapter.dart`
- **Objective:** If webOS SSAP exposes an IME focus event via subscription, stream it; if not (likely), stream emits a constant `false` with this documented as a known limitation (same strategy as Hisense); `LgAdapter.watchRemoteTextInputReady` delegates to transport
- **Testable done:** Stream is non-null and does not throw; emits `false` in fake transport
- **Deps:** T-3.1
- **Risk:** MEDIUM — webOS IME focus subscription may not exist
- **Skills:** `abstraction-domain-modeling`
- **Decision to log:** If SSAP has no IME subscription event, document in this file under Decisions
- **Status:** `pending`

---

#### T-3.3 · Gate `DeviceCapability.textInput` for LG behind env flag

- **File:** `domain/models/tv_brand_capabilities.dart` + `data/adapters/lg_adapter.dart`
- **Objective:** `TvBrandCapabilities.defaultCapabilities` for LG excludes `DeviceCapability.textInput` unless `bool.fromEnvironment('LG_ENABLE_TEXT_INPUT', defaultValue: false)` is true; `LgAdapter.supportsTextInput` reads same flag; flag only enabled in production after T-5.2 passes; mirrors `SAMSUNG_ENABLE_TEXT_INPUT` pattern
- **Testable done:** Default build has `supportsTextInput = false` for LG; flag-enabled build has `supportsTextInput = true`
- **Deps:** T-3.1
- **Risk:** LOW
- **Skills:** `configuration`
- **Status:** `pending`

---

### SG-4 · LG Adapter & Transport Test Lane

> Can begin after T-1.3. Grows as SG-2 and SG-3 complete. Absorbs TVREMOTE-16 unsupported-flow scope for LG.

---

#### T-4.1 · `lg_test_lane_test.dart` — unsupported command returns UI-safe result

- **File:** `test/lg_test_lane_test.dart` (new)
- **Objective:** `BrandRoutedRemoteCommandService` with a subset `LgAdapter` returns `isSuccess: false` with correct message for an unmapped command; `flutter test` passes; mirrors `samsung_test_lane_test.dart` structure
- **Testable done:** Test file created and green
- **Deps:** T-1.3, T-1.5
- **Risk:** LOW
- **Skills:** `test-creation-strategy`
- **Status:** `pending`

---

#### T-4.2 · Pairing and reconnection unit tests

- **File:** `test/lg_test_lane_test.dart`
- **Objective:** Tests cover: (a) first-time pair → client-key stored; (b) reconnect with stored key → completes without prompt; (c) pairing timeout → `LgPairingTimeoutException` surfaced as `CommandDispatchResult.failure`; (d) stale key → store cleared and session-expired exception thrown
- **Testable done:** All four cases pass via `FakeLgTransportClient`
- **Deps:** T-2.3, T-4.1
- **Risk:** LOW
- **Skills:** `test-creation-strategy`, `regression-prevention`
- **Status:** `pending`

---

#### T-4.3 · Text-input and compatibility unit tests

- **File:** `test/lg_test_lane_test.dart`
- **Objective:** (a) `sendText` when `supportsTextInput=false` → `CommandDispatchResult.unsupported`; (b) `sendText` when `supportsTextInput=true` (flag enabled) → success via fake; (c) IME unavailable (`TextInputCompatibilityException`) → `CommandDispatchResult.compatibility`
- **Testable done:** All three cases pass
- **Deps:** T-3.3, T-4.2
- **Risk:** LOW
- **Skills:** `test-creation-strategy`
- **Status:** `pending`

---

#### T-4.4 · Error and reconnect hook tests

- **File:** `test/lg_test_lane_test.dart`
- **Objective:** (a) transport throw → `CommandDispatchResult.failure` with message; (b) connection drop before command → reconnect attempted; (c) `flutter test` green for full `lg_test_lane_test.dart`
- **Testable done:** Full test file passes `flutter test`
- **Deps:** T-4.3
- **Risk:** LOW
- **Skills:** `regression-prevention`
- **Status:** `pending`

---

### SG-5 · Physical Validation

> Last. Requires SG-1–4 complete. Gates `LG_ENABLE_TEXT_INPUT` promotion.

---

#### T-5.1 · Physical smoke test — discovery, pairing, remote control

- **File:** `references/lg_hardware_validation.md` (create on completion)
- **Objective:** On physical LG webOS TV: (a) SSDP discovery finds the device; (b) pairing prompt appears and accepting stores the client-key; (c) power, volume up/down, dpad commands visibly reach the TV; (d) cold-restart reconnection works without re-prompting; (e) model, firmware version, and webOS version recorded in `references/lg_hardware_validation.md`
- **Testable done:** All five points verified and documented
- **Deps:** T-2.3, T-1.4
- **Risk:** HIGH — hardware/network environment; not automatable
- **Skills:** `test-interpretation-failure-diagnosis`
- **Status:** `pending`

---

#### T-5.2 · Physical validation — text-input / IME

- **File:** `references/lg_hardware_validation.md` (update)
- **Objective:** On physical LG webOS TV: (a) `insertText` injects text into a focused search field; (b) `sendEnterKey` triggers search; (c) webOS version and model recorded as "known-good for IME" in validation doc; (d) `LG_ENABLE_TEXT_INPUT` flag enabled for LG in `TvBrandCapabilities` only after this passes
- **Testable done:** IME scenario verified on hardware and documented
- **Deps:** T-3.1, T-3.2, T-5.1
- **Risk:** HIGH — IME behavior varies by webOS version; may not work on all models
- **Skills:** `test-interpretation-failure-diagnosis`
- **Status:** `pending`

---

## Dependency Graph

```
T-1.1 ──► T-1.2 ──► T-2.1 ──► T-2.2 ──► T-2.3 ──► T-3.1 ──► T-3.2 ──► T-3.3
     │                                       │                               │
     └──► T-1.3 ──► T-4.1                   └──────────────────────► T-5.1 ──► T-5.2
T-1.4 ──► T-1.5 ──► T-1.6                                                 (needs T-3.1,T-3.2)
          T-1.5 ──► T-4.1 ──► T-4.2 ──► T-4.3 ──► T-4.4
```

**Safe to parallelise:** T-1.1 and T-1.4 have no deps — start both immediately.
T-1.3 can be written immediately after T-1.1.

---

## Execution Order (recommended)

| Step | Tasks | Notes |
|---|---|---|
| 1 | T-1.1, T-1.4 | Interface + key mapper — no deps, safe to do together |
| 2 | T-1.2, T-1.3 | Real + fake transport clients |
| 3 | T-1.5, T-1.6 | Wire adapter + app |
| 4 | T-4.1 | First test lane coverage (unblocked after T-1.3 + T-1.5) |
| 5 | T-2.1, T-2.2 | Key store + pairing flow |
| 6 | T-2.3 | Reconnect with stored key |
| 7 | T-4.2 | Pairing unit tests |
| 8 | T-3.1, T-3.2, T-3.3 | IME transport + capability flag |
| 9 | T-4.3, T-4.4 | IME + error unit tests |
| 10 | T-5.1 | Physical hardware smoke test |
| 11 | T-5.2 | Physical IME validation |

---

## Scope Assumptions

1. LAN-only — no LG ThinQ cloud path; same Wi-Fi-first strategy as Samsung/Hisense.
2. D-pad and `back` use the pointer input socket (`ssap://com.webos.service.networkinput/getPointerInputSocket`), not SSAP key URIs. `RealLgTransportClient` manages the pointer socket separately.
3. `mute` requires current state to toggle — implementation calls `ssap://audio/getStatus` first or tracks mute state in memory.
4. Client-key storage uses `SharedPreferences` — no new packages.
5. `supportsTextInput` stays `false` for LG until T-5.2 physical validation confirms IME works.
6. If webOS SSAP has no IME focus subscription event, `watchRemoteTextInputReady` emits constant `false` (documented limitation — same as Hisense).

---

## Decisions Log

| Date | Decision | Rationale |
|---|---|---|
| 2026-04-21 | Follow existing Strategy + transport-injection pattern (not a new pattern) | Samsung and Hisense already use this; DA-7 requires consistency check before recommending new patterns |
| 2026-04-21 | Use SSAP WebSocket protocol — no official LG SDK for mobile | LG Connect SDK is for TV-side web apps; SSAP is the standard for phone-side control confirmed across aiowebostv, lgtv2, flutter-remote |
| 2026-04-21 | Reuse `SamsungTlsTrustStore` pattern for TLS cert bypass | LG self-signed cert problem is identical to Samsung; no new code needed |
| 2026-04-21 | Use `SharedPreferences` for client-key storage | Matches `RealSamsungPairingTokenStore` and `SharedPrefsLayoutRepository`; no new packages |
| 2026-04-21 | Gate `LG_ENABLE_TEXT_INPUT` behind env flag | Mirrors `SAMSUNG_ENABLE_TEXT_INPUT`; IME path requires physical validation before exposing in UI |

---

## References

- Home Assistant aiowebostv: https://github.com/home-assistant-libs/aiowebostv
- lgtv2 (Node.js): https://github.com/hobbyquaker/lgtv2
- LGwebOSTVRC (Python): https://github.com/douglasmun/LGwebOSTVRC
- flutter-remote (Dart/Flutter): https://github.com/e200/flutter-remote
- LG webOS developer docs: https://webostv.developer.lge.com
- webOS IME service API: https://www.webosose.org/docs/reference/ls2-api/com-webos-service-ime/
- webOS SSAP forum: https://forum.webostv.developer.lge.com/t/socket-connection-to-lg-tv/3360
