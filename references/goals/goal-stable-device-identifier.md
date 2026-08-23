# Goal: Unique, Stable Device Identifier

> **Superseded.** Implemented as `references/goals/goal-persistent-device-identity.md` on `feature/stable-device-identifier` (Phases 0–5; shipping in `1.5.0+20`). Keep this file only as the original analysis transcript.

**Branch:** `feature/command-drawer` (current)
**Status:** proposed — analysis only, **NOT FINALIZED** — **superseded by `goal-persistent-device-identity.md`**
**Related:** `references/goals/goal-command-drawer.md`, `references/goals/goal-variant-remote-layout.md` (both key persisted state off `deviceId`, and both inherit whatever this goal decides)
**Origin:** surfaced while explaining `LayoutRepository` — its `deviceId` key turned out to be IP-derived, not a stable device identity.

> ⚠️ **This document has not been verified or approved by the user.** Every claim under
> "Verified facts" was confirmed by direct source reads (file:line cited) as of 2026-08-21.
> Do not treat this as a spec. Everything under "Possible approaches" is unevaluated
> options, not a decision.

---

## Problem statement

`TvDevice.id` — the key nearly every piece of per-device persisted state hangs off — is
currently derived from the device's **brand + current IP address**, not from anything
inherent to the physical TV. If a TV's IP changes (router reboot, DHCP lease renewal, moving
the TV to a different network), the app generates a *different* `id` for what is, to the
user, the same TV — silently orphaning everything keyed by the old one.

## Verified facts (direct source reads, 2026-08-21)

1. **`TvDevice.id` is a plain `String`, no format contract** (`tv_device.dart:18`).
2. **Every discovery path builds it from brand + IP — including manual pairing, not just automated discovery.** Confirmed by reading each construction site (re-verified 2026-08-21):
   - `ssdp_device_discovery_service.dart:100` — `id: '${candidate.brand.name}-${candidate.ip}'`
   - `mdns_device_discovery_service.dart:95` — `id: 'androidtv-${ip.address.address}'`
   - `roku_ssdp_discovery_service.dart:71` — `id: 'roku-$ip'`
   - `pairing_page_data.dart:75` — `id: '${brand.name}-$protocolVariant-$ip'`, the **manual-IP entry path** (used when a user types a TV's IP directly, per `product_specs.md`'s documented SSDP-failure fallback) — same weakness, not something automated discovery alone causes.
   - No brand's path uses anything else — no MAC, no UUID, no serial number.
   - **`TvDevice.copyWith` never accepts an `id` parameter** (`tv_device.dart:25-37`) — always reuses `id: id` from the original. Confirms `id` is immutable for the life of a `TvDevice` object; it can never be quietly upgraded to something more stable later without constructing a brand-new object (and losing continuity with whatever was persisted under the old id).
3. **No stable identifier is captured anywhere in the domain model today.** `TvDeviceInfo` (`tv_device_info.dart`) has exactly three fields: `modelIdentifier`, `firmwareVersion`, `debugDetails` — no MAC/UUID/serial field exists to fall back on even if a protocol exposed one. Grepped `ssdp_device_discovery_service.dart`/`discovery_result_merger.dart` for `usn`/`udn`/`uuid` — no hits; if SSDP responses carry a USN (many UPnP devices do), this app doesn't currently parse or keep it.
4. **The blast radius is large — `deviceId` is the primary key for the entire saved-device feature, not just layout.** `DeviceRepository` (`application/device_repository.dart:3-18`) — the interface behind the whole "saved devices" list — keys *every* method on `deviceId`: `getLastSuccessfulPairingAt`, `saveDevice`, `removeSavedDevice`, `setLastSuccessfulPairingAt`, `setLastUsedDevice`, `saveDeviceSystemInfo`/`getDeviceSystemInfo`. An IP change orphans all of it at once, not just a saved layout.
5. **Pairing credentials have the same underlying fragility, via a different key.** `SamsungPairingTokenStore` (`samsung_pairing_token_store.dart:23-30`) keys tokens by `host` (the IP), not `deviceId` directly — but since `deviceId` is *also* IP-derived, an IP change invalidates both simultaneously: the saved device entry becomes unreachable under its old id, *and* the stored auth token becomes unreachable under its old host key, likely forcing a full re-pair-and-re-approve flow on the TV even though nothing about the pairing itself actually changed.
6. **This predates and is independent of the command-drawer/variant-layout goals** — `LayoutRepository` just inherited the same `deviceId` weakness by using the same key everything else already uses. Fixing this here would benefit both of those goals plus the entire saved-device feature, not something scoped newly for them.

## Why this matters now

Both `goal-command-drawer.md` and `goal-variant-remote-layout.md` persist meaningful
per-device state (positions, drawer membership) keyed by this same `deviceId`. Building
either on top of a silently-unstable key means a user's careful drawer/layout customization
can vanish the moment their TV's IP changes — a bad experience that has nothing to do with
either feature's own design, and worth fixing at the root rather than compensating for in
each feature separately.

## Possible approaches (unevaluated — for discussion)

1. **Capture a real stable identifier per protocol, where one exists.** SSDP/UPnP responses commonly include a USN containing a UUID; mDNS TXT records often carry a device id; some WebSocket handshakes (Samsung/LG) may expose a device UUID in their info payload. Needs per-brand investigation — not confirmed yet whether any currently-used protocol path actually exposes one that this app just isn't reading.
2. **MAC address as identity anchor.** More universally available than protocol-specific UUIDs, but requires network-level lookup (ARP table or similar), which has platform permission/reliability complications on both Android and iOS — not yet investigated whether this is even feasible within Flutter's networking APIs.
3. **Keep IP-based `id` for now, add a reconciliation step.** On rediscovery, if a device with the same brand + model + last-known-MAC (or similar heuristic) shows up at a new IP, offer to merge its saved state into the old entry rather than treating it as new. Doesn't require a stable identifier, but is heuristic and could misfire (two TVs of the same brand/model on the same network).
4. **Prompt the user to confirm/merge on apparent re-pair.** Least engineering-invasive, worst UX — "is this the TV you paired before?" on every IP change.

No recommendation yet — this needs the per-protocol investigation in option 1 before a real comparison is possible.

## Open questions

- Does any currently-used discovery/pairing protocol already expose a stable identifier this app simply isn't parsing out? (Needs investigation per brand: Samsung, LG, Hisense, Android TV, TCL variants, Roku.)
- If no protocol exposes one reliably across all brands, is a mixed strategy acceptable (stable id where available, IP-based fallback elsewhere), or does inconsistency across brands make that worse than a single uniform (if flawed) approach?
- Is this worth solving before or after the command-drawer/variant-layout goals ship? It's not a hard blocker for either (they'd just inherit the existing fragility), but fixing it first avoids building more state on top of a key known to be unstable.

## Relationship to other goals

`goal-command-drawer.md` and `goal-variant-remote-layout.md` don't need to block on this —
both already work correctly today under the existing (flawed) `deviceId`, same as the rest
of the app. This goal is about fixing the shared root cause, not a prerequisite either of
them strictly needs to function.

---
