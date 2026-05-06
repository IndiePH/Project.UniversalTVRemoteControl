# Goal: Android TV Adapter (v2 only)

**Branch:** `feature/android-tv-adapter`  
**Status:** pending  
**Protocol reference:** `references/guide-android-tv-remote-protocol.md`  
**Variant guide:** `references/guide-adding-protocol-variant.md`  
**Proto source (authoritative):** `tronikos/androidtvremote2` on GitHub — `remotemessage.proto` + `polo.proto`

## Scope

Full working `AndroidTvAdapter` — peer of `LgAdapter`, `SamsungAdapter`, `HisenseAdapter`.
v2 protocol only (`_androidtvremote2._tcp`, ports 6466/6467, protobuf, mutual TLS).
v1 is explicitly excluded: no constant, no branch, no adapter.
Default variant = v2 (the only variant).

## Naming convention

- Concrete implementation: named after the mechanism — `AndroidTvTcpTransportClient`
- Fake/test double: `FakeAndroidTvTransportClient`
- No "Real" prefix anywhere

## Decisions

- mDNS runs in parallel with existing SSDP (both services active in DI)
- Tasks 1–8 wire fake transport everywhere; Task 9 updates prod DI to real transport
- Tasks 5, 6, 7 have no mutual dependencies — order among them is flexible after Task 4
- Tasks 8 and 9 both build `android_tv_tcp_transport_client.dart`; Task 9 completes it

## Protocol verification policy

> **Every task that touches the wire protocol MUST re-read the source proto files and
> Python implementation before writing any code.** Do not rely solely on this goal file —
> treat the descriptions below as a starting map, not a specification. Cross-check each
> detail against the authoritative sources listed above and flag any discrepancy before
> implementing.
>
> This policy exists because protocol details were found to be incorrect in the first
> draft of this file and were only caught by fetching the actual source files.

---

## Verified protocol details (as of May 2026)

### Pairing protocol (`polo.proto` — from `tronikos/androidtvremote2`)

All pairing messages are wrapped in `OuterMessage`:
```
required uint32 protocol_version = 1 [default = 1]
required Status status = 2
optional PairingRequest    pairing_request     = 10
optional PairingRequestAck pairing_request_ack = 11
optional Options           options             = 20
optional Configuration     configuration       = 30
optional ConfigurationAck  configuration_ack   = 31
optional Secret            secret              = 40
optional SecretAck         secret_ack          = 41
```

Status enum: STATUS_OK=200, STATUS_ERROR=400, STATUS_BAD_CONFIGURATION=401, STATUS_BAD_SECRET=402

Full pairing exchange sequence:
1. Client sends `OuterMessage { pairing_request { service_name, client_name } }`
2. TV sends `OuterMessage { pairing_request_ack { server_name } }` — TV now shows PIN
3. Client sends `OuterMessage { options { input_encodings, output_encodings } }`
4. TV sends `OuterMessage { configuration { encoding, client_role } }`
5. Client sends `OuterMessage { configuration_ack }` (empty)
6. Client sends `OuterMessage { secret { secret: <computed_bytes> } }`
7. TV sends `OuterMessage { secret_ack { secret: <echo> } }` — pairing success

**Pairing code format:** 6 hexadecimal characters (e.g. `"F3A2C1"`) — NOT a 4-digit decimal PIN.
- Characters 0–1: verification/checksum byte
- Characters 2–5: used in secret computation

**Pairing secret formula (from Python source — exact):**
```python
h = hashlib.sha256()
h.update(bytes.fromhex(f"{client_modulus:X}"))
h.update(bytes.fromhex(f"0{client_exponent:X}"))
h.update(bytes.fromhex(f"{server_modulus:X}"))
h.update(bytes.fromhex(f"0{server_exponent:X}"))
h.update(bytes.fromhex(pairing_code[2:]))  # ← last 4 hex chars only
secret_bytes = h.digest()
```
Verification: `secret_bytes[0]` must equal `int(pairing_code[0:2], 16)`.
`client_modulus`, `client_exponent`, `server_modulus`, `server_exponent` are the RSA key
components from the respective certificates — NOT the full DER-encoded public key.

> ⚠️ **Verify before implementing Task 8:** The wire framing for the pairing channel
> (port 6467) likely uses a 4-byte big-endian length prefix before each protobuf message
> (consistent with the remote channel). Confirm by reading the Python connection code
> (`connection.py` or equivalent) before writing any socket I/O.

### Remote control protocol (`remotemessage.proto`)

`RemoteMessage` wrapper field numbers (partial — full list in proto file):
```
optional RemoteSetActive       remote_set_active     = 2
optional RemotePingRequest     remote_ping_request   = 8
optional RemotePingResponse    remote_ping_response  = 9
optional RemoteKeyInject       remote_key_inject     = 10   ← key events
optional RemoteImeKeyInject    remote_ime_key_inject = 20   ← text input
optional RemoteImeBatchEdit    remote_ime_batch_edit = 21
```

`RemoteKeyInject`:
```
required RemoteKeyCode  key_code  = 1
required RemoteDirection direction = 2
```

`RemoteDirection` enum — **NOT KEY_DOWN/KEY_UP**:
```
UNKNOWN_DIRECTION = 0
START_LONG        = 1   ← start of long press
END_LONG          = 2   ← end of long press
SHORT             = 3   ← normal tap/press  ← use this for standard button sends
```

`RemotePingRequest`: `{ required int32 val1 = 1; required int32 val2 = 2; }`
`RemotePingResponse`: `{ required int32 val1 = 1; }` ← echo val1 from request

`RemoteSetActive`: `{ required int32 active = 1; }` — send after connecting on port 6466

**Key codes:** `RemoteKeyCode` is a proto enum whose integer values match standard Android
`KeyEvent` constants. Verified values:
- KEYCODE_HOME=3, KEYCODE_BACK=4
- KEYCODE_DPAD_UP=19, KEYCODE_DPAD_DOWN=20, KEYCODE_DPAD_LEFT=21, KEYCODE_DPAD_RIGHT=22
- KEYCODE_DPAD_CENTER=23
- KEYCODE_VOLUME_UP=24, KEYCODE_VOLUME_DOWN=25, KEYCODE_POWER=26
- KEYCODE_MENU=82, KEYCODE_TV_POWER=177, KEYCODE_TV_INPUT=178

> ⚠️ **Verify before implementing Task 9:** Text input — the `RemoteImeKeyInject` message
> (field 20) has complex required sub-fields (`RemoteAppInfo`, `RemoteTextFieldStatus`)
> including counters and app package names. Before implementing `sendText`, read how the
> Python `androidtvremote2` library's `send_text_command` constructs this message. Do not
> assume the field layout — it is non-obvious and has mandatory fields that are not self-
> explanatory.

---

## Tasks

### Task 1 — Domain foundation
**Status:** done  
**Risk:** LOW  
**Deps:** none

Files to change:
- `lib/remote_control/domain/models/tv_brand.dart` — add `androidTv` value; add `'Android TV'` to `displayName` switch
- `lib/remote_control/domain/models/tv_capabilities.dart` — add `(TvBrand.androidTv, TvDevice.defaultProtocolVariant)` entry: `{keyCommands, powerControl, pinPairing}`
- `lib/remote_control/data/variant_resolution_registry.dart` — add catch-all entry for `androidTv` → `TvDevice.defaultProtocolVariant`
- `lib/remote_control/data/fake_device_discovery_service.dart` — add one fake Android TV device

**Testable objective:** project compiles with no exhaustive-switch warnings or analysis errors.

---

### Task 2 — Key mapper + protocol variants
**Status:** done  
**Risk:** LOW  
**Deps:** Task 1

New files to create:
- `lib/remote_control/data/adapters/android_tv/android_tv_protocol_variants.dart`
  - `defaultVariant = TvDevice.defaultProtocolVariant`
  - No v1 constant. No predicate needed (single variant, catch-all suffices).
- `lib/remote_control/data/adapters/android_tv/android_tv_key_mapper.dart`
  - Extends `CommandKeyMap`
  - Maps `RemoteCommand` → Android `KeyEvent` integer (the same integer values used in the `RemoteKeyCode` proto enum)
  - Verified key code integers (cross-check against `remotemessage.proto` `RemoteKeyCode` enum before writing):
    - dpadUp=19, dpadDown=20, dpadLeft=21, dpadRight=22, dpadOk=23
    - back=4, home=3
    - volumeUp=24, volumeDown=25, mute=164, power=26
    - channelUp=166, channelDown=167, menu=82
  - Streaming/app shortcuts (netflix, primeVideo, disneyPlus, playPause, input, web):
    look up `RemoteKeyCode` enum in `remotemessage.proto` for any matching constants
    (e.g. `KEYCODE_MEDIA_PLAY_PAUSE`). If no matching constant exists in the enum,
    return empty list and document as unsupported — do not invent codes.
  
  > ⚠️ **Before writing this file:** Read the full `RemoteKeyCode` enum in
  > `remotemessage.proto` (305 codes, 0–304). Use only codes present in that enum.
  > Do not use raw Android `KeyEvent` integer constants that are absent from the proto enum.

**Testable objective:** all `RemoteCommand` values either have a mapping from the verified proto enum or explicitly return empty; no invented codes.

---

### Task 3 — Transport interface + fake
**Status:** done  
**Risk:** LOW  
**Deps:** Task 1

New files to create:
- `lib/remote_control/data/adapters/android_tv/android_tv_transport_client.dart`
  - Abstract interface (mirrors `LgTransportClient` structure)
  - Methods: `connect`, `submitPairingCode`, `sendKey`, `sendText`, `probe`, `clearPairing`, `queryDeviceInfo`, `watchConnectionState`
  - Note: the pairing code for Android TV is a 6-character hex string (e.g. `"F3A2C1"`),
    not a 4-digit decimal PIN. The `submitPairingCode` parameter should be typed `String`
    with a doc comment noting the expected format.
- `lib/remote_control/debug/fake_android_tv_transport_client.dart`
  - Implements `AndroidTvTransportClient`
  - Mirrors `FakeLgTransportClient`: all methods complete without throwing
  - `submitPairingCode` completes immediately (accepts any string)
  - `connect` emits connected state

**Testable objective:** fake compiles; `connect` → `submitPairingCode` → `sendKey` sequence completes without error.

---

### Task 4 — Adapter + registries + DI wiring
**Status:** done  
**Risk:** MEDIUM  
**Deps:** Tasks 1, 2, 3

New file:
- `lib/remote_control/data/adapters/android_tv_adapter.dart`
  - Implements `TvBrandAdapter`
  - `brand` → `TvBrand.androidTv`
  - `protocolVariant` → `AndroidTvProtocolVariants.defaultVariant`
  - `supportsTextInput` → `true`
  - `supportedCommands` → `kCommonSupportedRemoteCommands`
  - `preparePairing`: connect to pairing port
  - `submitPairingCode`: delegates to `transportClient.submitPairingCode`
  - `sendCommand`: key lookup → `transportClient.sendKey`
  - `sendText`: `transportClient.sendText`
  - `queryDeviceInfo`: `transportClient.queryDeviceInfo` (returns empty `TvDeviceInfo()` — Android TV Remote Protocol does not expose model/firmware on this channel)
  - `probeConnection`, `unpairDevice`: delegate to transport

Files to update:
- `lib/remote_control/data/pre_pairing_steps_registry.dart` — add androidTv steps
  (e.g. "Ensure your Android TV / Google TV is on the same Wi-Fi network",
  "A PIN will appear on your TV screen — enter it when prompted")
- `lib/remote_control/data/pairing_progress_hint_registry.dart` — add androidTv hint
- `lib/app/localized_strings.dart` — add `pairingAndroidTvProgressHint`, `pairingAndroidTvPreStep0`, `pairingAndroidTvPreStep1`
- `lib/l10n/app_localizations_en.dart` — implement new string getters
- `lib/remote_control/configurations/remote_control_di_config.dart` — register `FakeAndroidTvTransportClient` in both `RemoteControlDiConfig` and `DebugRemoteControlDiConfig`; add `AndroidTvAdapter` to adapters list in both
- `lib/remote_control/debug/runtime_flags_template_debug.dart` — add `TvBrand.androidTv` case

**Testable objective (milestone):** app boots in debug mode; Android TV fake device appears in discovery list; tapping a command routes to fake transport without error.

---

### Task 5 — mDNS discovery
**Status:** done  
**Risk:** MEDIUM  
**Deps:** Task 1

Changes:
- `pubspec.yaml` — add `multicast_dns` dependency
- New `lib/remote_control/data/mdns_device_discovery_service.dart`
  - Scans for `_androidtvremote2._tcp` mDNS service type
  - Returns `TvDevice` entries with `brand: TvBrand.androidTv`
  - Uses `FlutterMulticastLock` on Android (already a dep)
- `lib/remote_control/configurations/remote_control_di_config.dart` — compose mDNS alongside SSDP:
  either create a `CompositeDeviceDiscoveryService` that merges results, or extend the
  existing service — choose the simpler approach at implementation time

**Testable objective:** a real Android TV / Google TV / Chromecast with Google TV device
on the local network appears in the discovery list without manual IP entry.

---

### Task 6 — Protobuf message types
**Status:** done  
**Risk:** LOW  
**Deps:** none

> ⚠️ **Before writing any code in this task:** Fetch and read the full content of
> `remotemessage.proto` and `polo.proto` from `tronikos/androidtvremote2`. Use only
> message names, field numbers, and types exactly as declared in those files. Do not
> infer structure from this goal file alone.

Changes:
- `pubspec.yaml` — add `protobuf` dependency
- New `lib/remote_control/data/adapters/android_tv/android_tv_remote_messages.dart`
  - Hand-written `GeneratedMessage` subclasses (no build-time code generation):
  - `RemoteMessage` wrapper — only implement the fields needed for this adapter:
    `remote_set_active=2`, `remote_ping_request=8`, `remote_ping_response=9`,
    `remote_key_inject=10`, `remote_ime_key_inject=20`
  - `RemoteSetActive` — `active` int32 field
  - `RemoteKeyInject` — `key_code` (int32/enum) + `direction` (RemoteDirection enum)
  - `RemoteDirection` enum: START_LONG=1, END_LONG=2, SHORT=3
  - `RemotePingRequest` — `val1` + `val2` int32
  - `RemotePingResponse` — `val1` int32
  - `RemoteImeKeyInject` + its required sub-messages — implement only after reading
    the Python `send_text_command` implementation; do not guess the field values
- New `lib/remote_control/data/adapters/android_tv/android_tv_pairing_messages.dart`
  - `OuterMessage` wrapper with all fields from `polo.proto`
  - `PairingRequest`, `PairingRequestAck`, `Options`, `Configuration`,
    `ConfigurationAck`, `Secret`, `SecretAck`
  - Status enum: STATUS_OK=200, STATUS_ERROR=400, STATUS_BAD_CONFIGURATION=401, STATUS_BAD_SECRET=402

Wire framing: each message is preceded by a 4-byte big-endian length (verify this against
the Python `connection.py` source before implementing the socket layer in Task 8).

**Testable objective:** a `RemoteKeyInject` for dpad-up (key_code=19, direction=SHORT=3)
serializes to a known byte sequence; a round-trip encode→decode produces the original values.

---

### Task 7 — Certificate management
**Status:** done  
**Risk:** MEDIUM  
**Deps:** none

Changes:
- `pubspec.yaml` — add a cert-generation package; evaluate `pointycastle` or `basic_utils`
  at task time and choose whichever provides the simplest API for:
  (a) RSA-2048 key pair generation, (b) self-signed X.509 cert creation, and
  (c) extracting the RSA modulus and exponent as big-endian byte arrays
  (needed for the pairing secret formula — see "Verified protocol details" above)
- New `lib/remote_control/data/adapters/android_tv/android_tv_certificate_store.dart`
  - On first use: generate RSA-2048 keypair + self-signed X.509 cert
  - Persist PEM-encoded private key + cert to `path_provider` app documents directory
  - Expose:
    - `SecurityContext clientContext` — loads client cert + key for `SecureSocket.connect`
    - `BigInt clientModulus` + `BigInt clientExponent` — RSA components for secret calc
    - `Future<void> storeServerCert(String host, Uint8List derBytes)` — persists server cert after pairing
    - `Future<(BigInt mod, BigInt exp)?> serverRsaComponents(String host)` — for secret calc
  - On subsequent launches: load from disk, skip generation

**Testable objective:** cert is generated once on first call; reloaded on a second cold call;
`SecurityContext` loads without throwing; RSA modulus and exponent bytes are non-empty and
consistent with the generated cert.

---

### Task 8 — Transport: pairing flow
**Status:** done  
**Risk:** MEDIUM  
**Deps:** Tasks 3, 6, 7

> ⚠️ **Before writing any code in this task:** Read the Python `androidtvremote2`
> pairing implementation in full (the `pair()` / `_pair()` methods). Verify:
> (1) the exact sequence of `OuterMessage` exchanges,
> (2) the wire framing (length prefix format and byte order),
> (3) the exact secret formula inputs (confirmed above but double-check edge cases
>     like odd-length hex modulus strings).

Creates (partial — pairing only):
- `lib/remote_control/data/adapters/android_tv/android_tv_tcp_transport_client.dart`
  - Implements `AndroidTvTransportClient`
  - **Pairing flow** (port 6467, mutual TLS via `SecureSocket`):
    1. `connect({deviceId})` for pairing — TCP + TLS to port 6467 using client cert
       from `AndroidTvCertificateStore`; capture server cert from TLS handshake
    2. Send `OuterMessage { pairing_request { service_name: 'androidtvremote2', client_name: 'OneRemote' } }`
    3. Await `OuterMessage { pairing_request_ack }` — TV shows PIN on screen
    4. Exchange `options` / `configuration` / `configuration_ack` messages
    5. `submitPairingCode({deviceId, code})` — compute secret bytes using the SHA-256
       formula from "Verified protocol details" above; send `OuterMessage { secret }`
    6. Await `OuterMessage { secret_ack }` — verify `status == STATUS_OK`; if
       `STATUS_BAD_SECRET` throw `AndroidTvPairingFailedException`
    7. Store server cert RSA components via `AndroidTvCertificateStore.storeServerCert`
  - `clearPairing`: clear stored server cert + disconnect
  - `probe`: TCP connect to port 6466 with 3-second timeout; close immediately

New exception file:
- `lib/remote_control/data/adapters/android_tv/android_tv_exceptions.dart`
  - `AndroidTvPairingFailedException`
  - `AndroidTvConnectionException`

**Testable objective:** successfully pairs with a real Android TV / Google TV device;
PIN code entry completes pairing; a subsequent `connect` on the remote port (6466) works
without re-triggering the PIN flow.

---

### Task 9 — Transport: command dispatch + lifecycle
**Status:** done  
**Risk:** MEDIUM  
**Deps:** Task 8

> ⚠️ **Before implementing `sendText`:** Read the Python `send_text_command` method in
> `androidtvremote2` and the `RemoteImeKeyInject` + `RemoteTextFieldStatus` + `RemoteAppInfo`
> message structure in `remotemessage.proto`. The required sub-fields are non-obvious.
> Do not implement text input by guessing field values.

Completes `android_tv_tcp_transport_client.dart`:
- **Remote control flow** (port 6466):
  1. `connect({deviceId})` (post-pairing) — TCP + mutual TLS to port 6466 using stored
     client cert; send `RemoteMessage { remote_set_active { active: 1 } }` to start session
  2. `sendKey({deviceId, keyCode})` — send `RemoteMessage { remote_key_inject { key_code, direction: SHORT } }`
     with wire-framing (4-byte length prefix); SHORT=3 is a standard tap
  3. `sendText({deviceId, text})` — send `RemoteMessage { remote_ime_key_inject { ... } }`
     per verified Python implementation; see ⚠️ note above
  4. Keepalive: on receiving `RemoteMessage { remote_ping_request }`, respond immediately
     with `RemoteMessage { remote_ping_response { val1: <echo request val1> } }`
  5. Reconnect on socket close; emit `ConnectionState.disconnected` → `ConnectionState.connecting`
     → `ConnectionState.connected` transitions
  6. `watchConnectionState` — stream backed by internal socket lifecycle events
  7. `queryDeviceInfo` — return `TvDeviceInfo()` (empty non-null; protocol does not
     expose model/firmware on this channel)

Also in this task:
- Update `lib/remote_control/configurations/remote_control_di_config.dart` —
  `RemoteControlDiConfig` (prod) now instantiates and registers `AndroidTvTcpTransportClient`;
  `DebugRemoteControlDiConfig` keeps `FakeAndroidTvTransportClient`

**Testable objective:** key events reach the TV and the correct on-screen action occurs;
connection survives a 60-second idle period (keepalive holds); disconnect + reconnect
works without re-pairing.
