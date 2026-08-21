# Goal: Persistent Device Identity

**Branch:** `feature/stable-device-identifier`
**Status:** decided — implementation in progress
**Decided:** 2026-08-21 (DT-2 confirmation recorded)
**Analysis source:** `references/goals/goal-stable-device-identifier.md` (borrowed from `feature/command-drawer`; temporary, to be deleted)
**Supporting reference:** `references/persistent-device-identity.md` — per-brand identifier sources, uniqueness, migration & reconciliation design.

---

## Problem

`TvDevice.id` is derived from **brand + current IP**, not anything inherent to the physical TV. A router reboot / DHCP renewal changes the IP, generating a different `id` for the same TV and orphaning everything keyed by the old one:

- Saved-device entry unreachable under old `id`.
- Pairing secrets keyed by host IP (`HostScopedSecretPersistence`) unreachable → forced re-pair.
- Layout/drawer state keyed by `deviceId` would vanish with it (affects unbuilt `goal-command-drawer` / `goal-variant-remote-layout`).
- Free-tier 1-device limit: the orphan counts against the slot, blocking the "new" device.

The retry timer (`remote_home_page.dart:377-389`) retries the dead address forever; no reconciliation exists. Verified facts live in the analysis doc.

---

## Decision — Option 1: stable `id` + mutable `host`

Make `TvDevice.id` the **stable** per-brand identifier (derived from an inherent property of the physical TV). Add a separate **mutable** `host` field for the current LAN IP. Transports read `device.host` instead of regex-extracting IP from `id`. All persisted state (saved-device list, layout, pairing secrets) is then keyed by the stable `id` and survives IP changes for free. Reconciliation becomes a one-field `host` update on rediscovery.

**Why over Option 2** (keep IP `id` for transports, add parallel `stableId`, re-key state): Option 2 keeps a hidden dependency — transports deriving location from identity via regex — which `architecture-governance` flags (DIP: depend on an explicit `host`, not a regex over an opaque string). Option 1 touches more files but uses one identity concept instead of two that must be kept in sync, and removes the regex-from-`id` pattern duplicated across 8 sites.

**Confirmed with user 2026-08-21:** Option 1, with Play data-safety caveats below, and confirmation the stable id is unique per physical TV (per-brand uniqueness in the reference doc).

---

## Per-brand stable identifier (summary — full analysis in reference doc)

| Brand | Source | Unique per TV | Confidence |
|---|---|---|---|
| Roku | `serial-number` from `/query/device-info` (already fetched, discarded) | Yes | High |
| Android TV | SHA-256 of TV's mTLS server cert (already stored) | Yes | High |
| Samsung (Tizen) | UPnP `USN`/`UDN` UUID from SSDP (already parsed for brand, not kept) | Yes | High |
| LG (webOS) | UPnP `USN`/`UDN` | Yes | High |
| Hisense (VIDAA) | UPnP `USN`/`UDN`, composite `udn+model+serial` fallback, IP fallback | Usually | Medium |

The stable id is **not secret** (observable on LAN); it replaces the *identity* key only. Pairing *secrets* stay in `flutter_secure_storage`, just re-keyed.

---

## Play Store / data-safety caveats

1. **No data leaves the device, no new data collected.** Stable id is local-only, not sent to any server in this plan. → No privacy policy / Data safety form change.
2. **Lossless, atomic-ish credential migration.** Move secrets from host-keyed to stableId-keyed secure storage; on interrupt, fall back to old key rather than force re-pair. Never delete old key until new one confirmed written.
3. **User-initiated deletion still fully works.** `removeSavedDevice` + per-brand `clearPairing`/`clearTokenForHost`/`clearKeyForHost`/`clearHost`/`clearServerCert` must clear both old host-keyed and new stableId-keyed entries during the migration window.
4. **No encryption weakening.** Stay on `flutter_secure_storage` (KeyStore AES-GCM). New `DeviceScopedSecretPersistence` is a key-naming change on the same backend.
5. **Backup rules unchanged.** `flutter_secure_storage` excluded from auto-backup by default; do not alter `android:allowBackup`/`fullBackupContent`.
6. **No new network calls / manifest change.** Hisense composite fallback fetches the SSDP descriptor XML over LAN, same traffic profile as the existing Roku `/query/device-info` fetch.
7. **Play Integrity / App Check unaffected** (server-side receipt validation, orthogonal — see `goal-pro-receipt-validation-remote-setup.md`).

---

## Implementation phases

- **Phase 0 — Domain model.** `TvDevice` gains required `host`; `id` becomes stable. `copyWith` gains `host` (keeps `id` immutable). `toJson`/`fromJson` add `host`; `fromJson` backfills `host` from legacy IP regex when absent. `TvDeviceInfo` gains optional `stableId`.
- **Phase 1 — Per-brand stable-id capture.** Roku serial (already fetched) → stamp at enrichment. Samsung/LG/Hisense parse `USN` UUID at SSDP discovery (already in header map). Hisense composite fallback + IP fallback. Android TV: SHA-256 of server cert on first successful pair; first pair stays IP-keyed, re-stamp after cert stored.
- **Phase 2 — Transport host resolution.** Replace `_ipv4.firstMatch(device.id)` with `device.host` in the 8 sites: `samsung_adapter.dart:57-61`, `lg_adapter.dart:35`, `hisense_adapter.dart:43`, `tcl_google_tv_adapter.dart:20`, `roku_http_transport_client.dart:26`, `tcl_legacy_tcp_transport_client.dart:29`, `discovery_result_merger.dart:8-34`, `remote_control_di_config.dart:156-167` (preserve `_tvHostOverride` debug escape hatch). Merger dedups by stable id.
- **Phase 3 — Persistence re-key + lazy migration.** `HostScopedSecretPersistence` → `DeviceScopedSecretPersistence`. Re-key `device_ids_v1`, `device_v1_<id>`, `remote_layout_v1_<id>`, and the four brand secret stores. One-time lazy migration on app start: derive stable id → write new keys → delete old. Fail → leave legacy entry, reconcile later.
- **Phase 4 — Reconciliation on rediscovery.** In `_loadInitialDevice` (`remote_home_page.dart:397-418`) and after discovery scans: match by stable id, update saved device's `host` via `copyWith(host:)`, re-persist. Retry timer then hits the live IP. No re-pair, no orphan.
- **Phase 5 — Free-tier orphan cleanup.** After Phase 4, orphans reconcile instead of duplicate. Optional one-time sweep: IP-keyed saved device unseen in N days → offer removal.
- **Phase 6 — Testing.** Unit: per-brand stable-id derivation (incl. Hisense composite + IP fallback), `fromJson` backfill, migration idempotency, migration interrupt → old key readable. Integration: router-reboot scenario (`.50` → `.73`), assert host updated, no re-pair, layout + secrets intact. Extend `shared_prefs_layout_repository_test.dart`, `discovery_result_merger_test.dart`, brand adapter host-resolution tests.

---

## Tradeoffs logged (DT-1)

- **Blast radius:** Phase 2 touches every adapter's host path — mechanical but wide. Justified by removing a hidden regex dependency; reversible only by full revert.
- **Hisense UDN reliability:** medium → mitigated by composite fallback; worst case degrades to today's IP-based behavior, never worse than now.
- **Android TV first-pair window:** stable id known only after cert stored on first successful pair. IP change before first pairing completes orphans — edge case, no worse than today.
- **Migration is the riskiest step** for data safety; designed lossless with old-key retention until new key confirmed.

---

## Sequencing vs. other goals

`goal-command-drawer.md` and `goal-variant-remote-layout.md` are unbuilt and key off `deviceId`. **This goal first** → they inherit a stable key for free. Doing it after means retrofitting migration onto already-shipped layout/drawer state. This answers the "before or after" open question in the analysis doc.

---

## Done criteria

- Router-reboot scenario test passes: saved device rediscovered at new IP, `host` updated, no re-pair, layout + secrets intact.
- All 8 host-resolution sites read `device.host`; no `_ipv4.firstMatch(device.id)` remains in transport/adapter code.
- Migration is idempotent and interrupt-safe (unit-tested).
- `removeSavedDevice`/unpair clears both legacy and new keys during migration window.
- No privacy policy / Data safety form change required (verified: no data leaves device).
- Existing tests green; new tests added per Phase 6.
