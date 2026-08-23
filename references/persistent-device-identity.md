# Reference: Persistent Device Identity

Supporting detail for `references/goals/goal-persistent-device-identity.md`. Per-brand identifier sources, uniqueness analysis, identity string formats, and the migration/reconciliation design.

---

## Identity model

- `TvDevice.id` — **stable**, per-brand, derived from an inherent property of the physical TV. Immutable for the life of a `TvDevice` object (matches today's `copyWith` contract, `tv_device.dart:25-37`). Key for all persisted state.
- `TvDevice.host` — **mutable**, the current LAN IPv4. Transport-only. Transports read this instead of regex-parsing `id`.

---

## Per-brand stable identifier sources & uniqueness

### Roku — `serial-number`
- Source: `GET http://<host>:8060/query/device-info`, XML attribute `serial-number`.
- **Already fetched** at `roku_http_transport_client.dart:79` but only stuffed into `TvDeviceInfo.modelIdentifier` for debug; discarded as identity.
- Unique per physical Roku device (manufacturer serial). Confidence: **high**.
- Format: `roku-<serial>`.

### Android TV / Google TV — server certificate fingerprint
- Source: the TV's mTLS server certificate, **already stored** per host at `android_tv_certificate_store.dart:109-153` (`android_tv_server_<hostTag>.cert.der`).
- Compute `sha256(serverCertDer)` as the stable id.
- The TV generates one cert at first boot and keeps it → unique per device. Confidence: **high**.
- Format: `androidtv-<sha256hex>`.
- **First-pair window:** the cert is only available after the first successful pairing completes. The very first pair is therefore IP-keyed; once the cert is stored, re-stamp the saved device's `id` to `androidtv-<sha256>` and keep `host`. Subsequent reconnects benefit. An IP change *before* first pairing completes orphans — edge case, no worse than today.

### Samsung (Tizen) — UPnP USN/UDN
- Source: SSDP `USN` header. **Already parsed** into the header map and read for brand inference (`ssdp_brand_inference.dart:9`) but not kept as identity.
- USN form typically `uuid:<uuid>::upnp:rootdevice` or `uuid:<uuid>`. Extract the UUID.
- Tizen emits a stable per-device UDN. Confidence: **high**.
- Fallback: fetch the device descriptor XML at the `LOCATION` URL; read `<UDN>` (and `<serialNumber>` if present).
- Format: `samsung-<udn>`.

### LG (webOS) — UPnP USN/UDN
- Same source/parse path as Samsung. webOS emits a stable per-device UDN. Confidence: **high**.
- Format: `lg-<udn>`.
- Secondary signal: `ssap://system/getSystemInfo` (`lg_websocket_transport_client.dart:574`) may expose additional device info; not required for identity.

### Hisense (VIDAA) — USN/UDN with composite + IP fallback
- VIDAA UDN stability is **firmware-dependent**: some builds emit a stable per-device UDN, others emit a non-unique or regenerating one. Confidence: **medium**.
- Strategy (layered):
  1. Parse `USN` UUID → `hisense-<udn>`.
  2. If UDN is empty or collides with another device's UDN on the same network, fetch the descriptor XML and compose `hisense-<udn>:<modelName>:<serialNumber>`.
  3. If all fail, fall back to the current IP-based id `hisense-<ip>` for that one device — graceful degradation, never a hard failure.
- This is the one brand where the strategy is not uniform; inconsistency on one brand is better than a wrong identity on it (answers the analysis doc's "mixed strategy acceptable?" open question: **yes, with IP fallback**).

### Uniqueness note
All chosen identifiers are unique per **physical TV**, so two identical units (same SKU/model) in one house get different ids — which is exactly why SKU/model alone is not used. The identifiers are **not secret** (observable on LAN); they replace the *identity* key only. Pairing *secrets* remain in `flutter_secure_storage`, re-keyed by stable id.

---

## Migration design (lossless, lazy)

Migration is **lazy on rediscovery / pairing enrichment**, not a one-shot wipe on app
start. Legacy IP-keyed records remain usable until a stable identity can be proven.

1. Keep loading legacy saved devices keyed by old IP-based `id`.
2. When discovery or pairing proves a stable id for the same physical TV:
   - Android TV: certificate fingerprint when the peer cert is already known.
   - Roku: serial from `/query/device-info` when available.
   - Samsung/LG/Hisense: SSDP UDN (or Hisense composite / IP fallback).
3. On a conservative exact host + brand match (or certificate proof for Android TV):
   - Write the device, secrets preference, and layout under the new stable-id key
     before retiring the old active device record.
   - Layout copy happens before device re-key; legacy layout retirement happens only
     after device migration succeeds.
   - Legacy host-keyed pairing secrets are retained as a fallback during the window.
4. If derivation or matching fails: leave the legacy entry in place and keep working
   off the IP-based id until a later scan can reconcile it. Never lose data mid-migration.

**Idempotent:** re-running migration finds new-key entries already present and skips or
retries safely. **Interrupt-safe:** a kill mid-migration leaves either the old key
(preferred) or both keys; never neither.

---

## Reconciliation design

After discovery scans (`PairingPageData.reconcileDiscovery` via
`DeviceReconciliationService`) and during active reconnect:

1. Build the set of discovered devices (stable id when proven; otherwise IP-derived).
2. For each saved device with a stable id, match discovered devices by that id.
3. On match: update the saved device's `host` to the discovered IP via `copyWith(host:)`
   and re-persist. Home reconnect then uses the live host.
4. For remaining legacy IP-keyed saved devices, propose a re-key only on an unambiguous
   exact host + brand match; skip ambiguous or already-moved hosts.
5. On no match yet: keep retrying the last-known host — no regression.

Result: no re-pair, no orphan, layout/drawer/saved-device state all survive an IP change
when identity can be proven.

---

## Legacy orphan cleanup

Phase 5 tracks only non-active devices whose `id` still contains an IP
address. A successful discovery scan records `lastSeenAt` when exactly one
discovered device has the same brand and resolved host, even if discovery now
reports a stable id for that TV.

If a legacy record has no timestamp, the first scan after this feature ships
starts a 30-day grace period. A record unseen for 30 days is presented to the
user for confirmation; it is never deleted automatically. Confirmed removal
unpairs the device, removes its saved-device record, and deletes the
`remote_layout_v1_<legacyId>` layout key. Existing free-tier cleanup remains
unchanged because it already removes non-active saved devices.

The Android TV certificate probe can prove identity for already-paired TVs
whose host changes, but the generic legacy migration remains conservative when
an old IP-keyed record has already moved to a different host. In that case the
old device and layout records remain available rather than being guessed as a
different physical TV.

---

## Current branch implementation status

Phases 0–5 are implemented on `feature/stable-device-identifier`. The shipped
shape is:

- `TvDevice.id` is the internal stable identity when proven; the LAN IP remains
  in `host` and user-facing display text.
- Discovery reconciliation updates hosts and preserves saved-device, layout, and
  pairing state across IP changes.
- Legacy host-keyed secrets remain a fallback, while device-scoped secrets are
  preferred.
- Legacy IP-keyed orphan cleanup is confirmation-only, has a 30-day grace
  period, excludes the active device, and removes its layout when confirmed.

Phase 6 remains the final validation step: complete the router-reboot
integration scenario and interrupted-migration fallback coverage, then record
the verification result in the goal and changelog.

---

## File touchpoints

Domain: `tv_device.dart`, `tv_device_info.dart`.
Discovery: `ssdp_device_discovery_service.dart`, `mdns_device_discovery_service.dart`, `roku_ssdp_discovery_service.dart`, `discovery_result_merger.dart`, `pairing_page_data.dart` (manual-IP path).
Adapters/transports (host resolution): `samsung_adapter.dart`, `lg_adapter.dart`, `hisense_adapter.dart`, `tcl_google_tv_adapter.dart`, `roku_http_transport_client.dart`, `tcl_legacy_tcp_transport_client.dart`, `android_tv_tcp_transport_client.dart`.
Pairing enrichment: `pairing_page_coordinator.dart` (stamp stable id + host on the enriched device).
Persistence: `persistence/legacy/legacy_host_scoped_secret_persistence.dart` → `device_scoped_secret_persistence.dart`, `persistence/legacy/legacy_secure_host_scoped_secret_persistence.dart`, `samsung_pairing_token_store.dart`, `lg_pairing_key_store.dart`, `hisense_pairing_auth_store.dart`, `android_tv_certificate_store.dart`, `shared_prefs_device_repository.dart`, `shared_prefs_layout_repository.dart`.
DI: `remote_control_di_config.dart` (`_resolveHost` → `device.host`).
Reconciliation: `remote_home_page.dart` (`_loadInitialDevice`, `_startConnectionRetry`).
Tests: `legacy_device_orphan_detector_test.dart`, `shared_prefs_device_last_seen_test.dart`, `shared_prefs_layout_repository_test.dart`, `discovery_result_merger_test.dart`, `shared_prefs_device_repository`-adjacent, brand adapter host-resolution tests, plus new migration/reconciliation tests.
