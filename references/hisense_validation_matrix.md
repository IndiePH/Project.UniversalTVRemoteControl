# Hisense Physical Validation Matrix

Tracks physical Hisense validation for `TVREMOTE-7` (Android SSDP discovery
re-validation after multicast-lock hardening) and `TVREMOTE-51` (Hisense test
lane), aligned with implementation threads under `TVREMOTE-36`.

## Scope

- SSDP discovery on Android APK (multicast-lock + Hisense fingerprint headers)
- Discover -> pair (4-digit PIN path) -> remote key control
- Reconnect and session continuity after Wi-Fi blip / app resume
- Fallback path when SSDP empty (manual IP + `TV_HOST_OVERRIDE`)

## Discovery code under test

- `lib/remote_control/data/ssdp_device_discovery_service.dart`
  - Android: `FlutterMulticastLock.acquireMulticastLock()` for the scan window
  - M-SEARCH targets: `ssdp:all`, `upnp:rootdevice`, `MediaRenderer:1`,
    `MediaServer:1`
  - Brand fingerprint probes `server` / `st` / `nt` / `usn` / `location`;
    Hisense matched on `hisense` | `vidaa` | `hiview`
- `lib/remote_control/data/adapters/hisense/hisense_mqtt_transport_client.dart`
  - VIDAA MQTT on port `36669` (TLS, self-signed cert allowed; plaintext via
    `--dart-define=HISENSE_MQTT_PLAINTEXT=true`)

## Runbook (Android APK on phone, real Hisense TV)

1. **Build & install**
   - `flutter build apk --release` (real transports by default; see README
     "Current Runtime Modes")
   - Install on a physical Android phone
2. **Network setup**
   - Phone + TV on the same Wi-Fi SSID and same VLAN
   - Confirm router has **AP isolation OFF** (a.k.a. client isolation,
     guest-network isolation). If on, SSDP multicast is dropped between
     clients and discovery will always be empty.
   - Note 2.4 GHz vs 5 GHz band; some consumer APs filter multicast
     differently per band.
3. **Baseline scan (no overrides)**
   - Launch app -> Pair -> Scan
   - Record: scan duration, devices listed, whether Hisense entry appears
4. **If empty, capture evidence before fallback**
   - Re-run scan; if still empty, attach a packet capture (PCAPdroid /
     Wireshark on the AP) of the M-SEARCH window if possible
   - Note: did Samsung / LG appear? (isolates Hisense-only vs network issue)
5. **Fallback A — manual IP via pairing UI**
   - Find TV IP from router admin UI or TV `Network -> Information`
   - Pair -> Manual add -> brand: Hisense -> IP -> attempt PIN flow
6. **Fallback B — `TV_HOST_OVERRIDE` (single-TV lab)**
   - Rebuild with `--dart-define=TV_HOST_OVERRIDE=<tv-ip>`
   - Useful when even manual add is blocked by other UI state
7. **Pairing + commands**
   - Hisense PIN dialog appears on first connect; enter 4-digit code shown
     on TV
   - Test core keys (power-toggle awareness, volume, d-pad, OK, home, back)
   - Test reconnect: lock phone, idle 60s, unlock, send a key
8. **Cleanup**
   - Remove saved device if validating a fresh pair next run

## Environment template

- App build / commit:
- Phone model / Android version:
- Router model / firmware:
- Wi-Fi band (2.4 / 5 GHz):
- AP isolation: on / off
- Runtime flags:
  - `USE_FAKE_TRANSPORTS=false`
  - `TV_HOST_OVERRIDE=`
  - `HISENSE_MQTT_PLAINTEXT=`
  - `HISENSE_MQTT_CLIENT_ID=`

## Known-good Matrix

| Date | TV model | Firmware | SSDP scan | Manual-IP pair | PIN flow | Keys | Reconnect | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-05-22 | Hisense TV |  | pass | pass | pass | pass | pass | Android APK; SSDP discovered TV on scan; manual-IP fallback not required on this hardware |

## Findings (running log)

- _2026-05-14_ — Code review parity check: `SsdpDeviceDiscoveryService`
  acquires multicast lock on Android, fingerprint covers
  `hisense` / `vidaa` / `hiview`, M-SEARCH includes `MediaServer:1`. No
  regression vs shipped Task 1.1 hardening. Awaiting physical-device run to
  fill the known-good matrix.
- _2026-05-22_ — Automated regression (**TVREMOTE-7** C1): unit tests in
  `test/lib/remote_control/data/ssdp_brand_inference_test.dart` lock Hisense
  SSDP fingerprints (`hisense` / `vidaa` / `hiview` + `nt` in probe text).
- _2026-05-22_ — Physical validation (**TVREMOTE-7**): Hisense TV — SSDP scan,
  manual-IP pair, PIN flow, keys, reconnect **pass** (known-good matrix row).
  Fallback policy unchanged (manual IP + `TV_HOST_OVERRIDE`; port-`36669`
  sweep still deferred — SSDP succeeded on validated hardware).

## Fallback Path Decision (TVREMOTE-7 AC)

**Decision (today):** Keep **manual IP via the pairing UI** as the primary
fallback when SSDP returns empty. Continue to support **`TV_HOST_OVERRIDE`**
for single-TV lab runs. **Defer** an active port-`36669` LAN sweep.

**Rationale**

- The pairing screen already exposes manual brand + IP add (`PairingPage`
  manual-add section + IPv4 validation), so the user-facing recovery path
  exists with zero new code.
- `TV_HOST_OVERRIDE` is wired through `RemoteControlDiConfig._resolveHost`
  for both Samsung and Hisense transports — sufficient for lab repro of
  hardware that never broadcasts UPnP.
- A blind port-`36669` sweep would: (a) generate non-trivial LAN traffic
  on every scan, (b) require extra permissions / mDNS-style discipline to
  stay friendly to dense home networks, and (c) only help if Hisense MQTT
  itself is reachable from the phone — which is already what manual IP
  proves with one tap and no new scanning surface.
- Hisense MQTT requires a 4-digit PIN before any commands succeed, so a
  port sweep cannot replace pairing UX anyway; it would only shorten one
  manual step.

**Trigger to revisit (would promote port-sweep fallback to in-scope)**

- Multiple validated home routers (AP isolation off, multicast confirmed
  working for Samsung / LG) still produce empty Hisense SSDP responses
  after this runbook is exercised on ≥2 Hisense models.
- AND user research shows the "manual IP" tap is a measurable drop-off
  point in onboarding.

**Out of scope for TVREMOTE-7**

- Reworking SSDP search targets beyond the current four (`ssdp:all`,
  `upnp:rootdevice`, `MediaRenderer:1`, `MediaServer:1`).
- Adding a separate mDNS / WS-Discovery path.
- Per-brand discovery code branches (current shared SSDP service stays the
  single discovery seam).

## Regression Notes

- Store concise failures with reproduction hints and mitigation notes.
- Link Jira follow-ups when new issues are identified (e.g. router-specific
  multicast bugs, firmware-specific empty-header responses).

