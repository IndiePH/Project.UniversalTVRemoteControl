# Goal: Persistent Device Identity

**Branch:** `feature/stable-device-identifier`
**Status:** Phases 0–5 implemented — Phase 6 validation pending
**Decided:** 2026-08-21 (DT-2 confirmation recorded)
**Supporting reference:** `references/persistent-device-identity.md` — per-brand identifier sources, uniqueness, migration & reconciliation design.

---

## Problem

`TvDevice.id` is derived from **brand + current IP**, not anything inherent to the physical TV. A router reboot / DHCP renewal changes the IP, generating a different `id` for the same TV and orphaning everything keyed by the old one:

- Saved-device entry unreachable under old `id`.
- Pairing secrets keyed by host IP (legacy host-scoped secure storage) unreachable → forced re-pair.
- Layout/drawer state keyed by `deviceId` would vanish with it (command drawer is now shipped; variant default layouts remain plumbing).
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

- **Phase 0 — Domain model (complete).** Added nullable `host` with `resolvedHost` backfill, persisted host serialization, and transitional stable-id metadata without forcing a broad constructor migration.
- **Phase 1 — Per-brand stable-id capture (complete).** Stable identifiers are captured from discovery or pairing enrichment: SSDP UDNs where available and Android TV server-certificate fingerprints after pairing.
- **Phase 2 — Transport host resolution (complete).** Adapters, discovery merging, transport clients, and DI resolution use the explicit host path while retaining the legacy IP-derived fallback.
- **Phase 3 — Secrets-first persistence migration (complete).** Device-scoped secret persistence is preferred, while legacy host-keyed secrets remain available as a fallback during migration.
- **Phase 4 — Identity transition and reconciliation (complete).** `TvDevice.id` is the stable identity when proven; discovery updates the mutable host, conservatively re-keys saved-device/layout state, and preserves legacy records when identity cannot be proven.
- **Phase 5 — Legacy orphan cleanup (complete).** Non-active IP-keyed records receive persisted `lastSeenAt` tracking. After a 30-day grace period, non-free-tier users receive an explicit cleanup prompt that removes pairing data, the saved record, and its layout. Existing free-tier cleanup remains in place.
- **Phase 6 — Final validation (next).** Add or strengthen the router-reboot integration scenario and interrupted-migration fallback coverage, then record the final verification result.

---

## Verification baseline

- `flutter test` — 576 tests passed; 1 test skipped (after merging `main` + this goal).
- `flutter analyze` — no issues found.
- App version for this release: `1.5.0+20`.
- The broad suite is green; the remaining Phase 6 gap is explicit router-reboot
  integration and interrupted-migration fallback coverage.

---

## Tradeoffs logged (DT-1)

- **Blast radius:** Phase 2 touches every adapter's host path — mechanical but wide. Justified by removing a hidden regex dependency; reversible only by full revert.
- **Hisense UDN reliability:** medium → mitigated by composite fallback; worst case degrades to today's IP-based behavior, never worse than now.
- **Android TV first-pair window:** stable id known only after cert stored on first successful pair. IP change before first pairing completes orphans — edge case, no worse than today.
- **Migration is the riskiest step** for data safety; designed lossless with old-key retention until new key confirmed.
- **Android legacy changed-IP exception:** a legacy IP-keyed record whose host changed before stable-id migration cannot be matched with certainty by the generic reconciliation path; its old layout and pairing record remain until explicit cleanup or a future identity proof.
- **Orphan cleanup safety:** last-seen tracking starts on feature rollout, uses a 30-day grace period, excludes the active device, and requires explicit confirmation before deleting the saved record, pairing data, or layout.

---

## Sequencing vs. other goals

Command-drawer and variant-layout work key persisted layout state off `deviceId`. **This goal first** → they inherit a stable key for free. The command drawer is now shipped on `main` (merged into this branch); per-variant default layouts are still an empty `RemoteLayoutDefaults` map. Doing identity after those would have meant retrofitting migration onto already-shipped layout/drawer state.

---

## Done criteria

- Router-reboot scenario test passes: saved device rediscovered at new IP, `host` updated, no re-pair, layout + secrets intact.
- All 8 host-resolution sites read `device.host`; no `_ipv4.firstMatch(device.id)` remains in transport/adapter code.
- Migration is idempotent and interrupt-safe (unit-tested).
- `removeSavedDevice`/unpair clears both legacy and new keys during migration window.
- Stale legacy records are never removed automatically; confirmed cleanup also removes their device-scoped layout key.
- No privacy policy / Data safety form change required (verified: no data leaves device).
- Existing tests green; Phase 6 integration and interrupted-migration coverage remains the final validation step.
