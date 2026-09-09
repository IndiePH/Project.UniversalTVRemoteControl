# Goal: Automatic Reconnection Resilience

**Status:** TENTATIVE — baseline breakdown only, **NOT FINALIZED**. To be updated with proposed
diffs and re-confirmed before any code is written.
**Branch:** `fix/reconnection` (current)
**Depends on:** `references/goals/goal-persistent-device-identity.md` (Phases 0–5, shipped) — this
goal treats that work as a completed foundation and does not reopen it. It extends identity
coverage and adds the automation layer that foundation does not itself provide.
**Origin:** Surfaced while diagnosing a real incident — a paired Android TV failed to reconnect
for several hours after two router restarts, despite being network-reachable (Wi-Fi + internet)
the entire time.

> ⚠️ This document is a tentative baseline, not an approved plan. It captures what was discussed
> and agreed in conversation. Sub-goals below have agreed *designs*; most do not yet have written
> diffs. Do not treat Status fields other than "design agreed" as implementation-ready.

---

## Problem

Two independent gaps were found, confirmed against actual code and one real incident. The first
is primary — it matters regardless of which identity signal a device has available at any given
moment, since some devices are bound to be IP-only some of the time. The second is a narrower,
Android-TV-specific issue on top of it.

1. **Neither device-connection screen retries or reconciles automatically.** Traced in both:
   - The remote/home page redials the exact same last-known host every 5 seconds, forever, with
     no reconciliation and no escalation — confirmed via `remote_home_page.dart`'s existing retry
     timer.
   - The paired-list (pairing) page's per-device reachability indicator runs one probe per manual
     rescan; the page's own reconciliation pass already runs on every scan but is fire-and-forget
     (`unawaited`), so a successful reconciliation never triggers a re-probe within the same scan.
   - Net effect, consistent with the triggering incident: a device that most likely already had a
     correct stable id (inferred from how it reconnected as the same paired entry rather than
     appearing as a new device — not independently verified) took hours to reconnect, purely
     because nothing retried or re-checked automatically while the app was open on neither screen,
     or while a transient port failure persisted. This is the primary bug — reconciliation is
     inevitable and necessary no matter what identity signal ends up being available, and today
     nothing makes it run on its own.

2. **Android TV's stable id additionally requires a live connection to reconfirm.** The stable id
   captured at pairing time (SHA-256 of the TV's certificate, per
   `goal-persistent-device-identity.md` Phase 1) is reliable *at the moment of pairing*, but
   reconfirming or re-deriving it during any later discovery scan currently requires a live,
   successful TLS handshake to the TV's remote-control port (6466). That is the same port that was
   confirmed unreachable — for hours — during the triggering incident, even while the TV remained
   reachable via Wi-Fi/mDNS/internet the entire time. This narrows the odds that even an automatic
   reconciliation pass (once #1 is fixed) succeeds on a given attempt for this device class.

3. **Identity source availability is not guaranteed and not uniform across devices.** Some
   Android TV firmware may not advertise a Bluetooth MAC via mDNS at all (unverified either way
   for the reporting user's own hardware); manually-added devices of any brand have no passive
   identity source today. Reconciliation must therefore work correctly across a *mixed*
   population — some devices identified by `bt`-derived id, some by cert-derived id, some still
   only by IP — not assume any one source is universally present.

   **Roku is a sharper case than the above implies, and is not addressed by any task below.**
   Unlike Android TV, Roku's discovery layer never attempts to re-derive its stable id (the ECP
   serial number, captured once at pairing) on any later scan — there is no enrichment step for
   Roku at all, fragile or otherwise. This means a Roku device that changes IP after pairing
   cannot be matched by reconciliation even once SG1/SG2 make it run automatically, because the
   main matching pass requires the *freshly discovered* device to also carry a stable id, and
   Roku's discovery never produces one. No fix for this was discussed or designed in this
   conversation — flagged here as a known, currently out-of-scope gap, not something SG1–SG4
   resolves.

---

## Decisions (tentative — logged per DT-1)

### D-1: No new shared coordinator service between the two pages
Both pages already receive `RemoteCommandService`, `DeviceDiscoveryService`, and
`DeviceRepository` from the same DI container (verified directly in
`remote_home_page.dart` and `pairing_page.dart`). The only genuinely missing piece — in-flight
retry/backoff bookkeeping — is bounded to each screen's own lifecycle, not shared state. Confirmed
with user: build each screen's retry logic against the existing shared services rather than
introducing a new singleton.

### D-2: Out of scope — recovery while the app is fully closed (proposed default, not explicitly confirmed)
Recovering during a multi-hour window while the app process itself isn't running would require a
platform background mechanism (Android WorkManager or a foreground service), with its own battery
and OS-policy tradeoffs. This was offered to the user as a scope-boundary question; the question
itself was not answered (a follow-up addressed the separate architecture question that became D-1
instead). Treated here as the working default since it was never challenged, but it should be
explicitly confirmed, not assumed settled.

### D-3: Automatic reconciliation triggering is the primary fix; identity-signal work is complementary
Confirmed with user: the fix that matters regardless of circumstance is making reconciliation run
automatically (SG1, SG2 below) — it doesn't depend on or wait for the bt/cert work (SG3, SG4).
Those improve the *odds* reconciliation succeeds for Android TV specifically; they are not
prerequisites for SG1/SG2, and SG1/SG2 should not be blocked on them.

### D-4: `bt`-derived identity requires cert confirmation before being trusted
A real-world collision case was found (Home Assistant GitHub issue #134867 — two distinct TiVo
Stream 4K units, made by SEI Robotics, reporting the identical Bluetooth MAC). `bt` is treated as
a fast *candidate-finding* signal, not sufficient on its own to merge two device records — the
existing cert-based identity must confirm the match first.

### D-5: Reconciliation must handle bt-ids, cert-ids, and legacy IP-ids side by side
Because `bt` availability varies by device/firmware (unverified, per-device), the discovery and
reconciliation logic must not assume any single identity source is universally present — a
network may simultaneously contain devices identified by any of the three schemes.

### D-6: Home-page retry cycle repeats indefinitely; escalation stays flat per lap; wait duration may grow
Confirmed with user: the fast-phase and escalation-phase behavior stays identical on every lap
("flat") — same attempt count, same cadence, same single reconciliation pass. The wait period
between laps may grow across successive laps (exact curve and cap: **open**, see below).

---

## Sub-goals and tasks

### SG1: Automatic, self-recovering reconnection on the remote/home page

#### Task T1.1: Implement the repeating fast → escalate → wait cycle
Objective: `remote_home_page.dart`'s connection retry becomes: fast phase (~3 attempts at 5s) →
escalation (one discovery+reconcile pass, then a connect attempt) → on continued failure, a single
wait period displayed as "Connection error... retrying in Xs [retry-now icon]" with a live
per-second countdown → on timeout or manual tap, loop back to the fast phase. Repeats indefinitely
while the page is open and disconnected.
Detail: Reuses `PairingPageData.discoverDevices`/`reconcileDiscovery` (already shared via DI, per
D-1) rather than new discovery plumbing. Manual tap cancels the wait and restarts the cycle from
the fast phase, not just a single immediate retry. Needs `DeviceIdentityRegistry` threaded into
`RemoteHomePage`'s constructor (already a GetIt singleton elsewhere in the app). Does not depend on
SG3/SG4 — works against whatever identity sources reconciliation already supports today.
Skills: language-specific-implementation, clean-code-solid, framework-mastery
Depends-on: []
Status: design fully agreed across multiple rounds of discussion; a diff exists in conversation
history for an earlier, since-revised shape of this design — needs a fresh diff against the
current agreed shape before implementation.
Risk-hint: MEDIUM — new state machine in a heavily-used screen

#### Task T1.2: Grow the wait duration across successive laps
Objective: The wait period (T1.1) increases on each successive lap of the outer cycle rather than
staying at a fixed duration indefinitely, while the fast phase and escalation phase stay identical
every lap.
Detail: Growth curve and cap are **open** — not yet decided. Needs a follow-up decision on: starting
duration, growth factor/step, and a maximum ceiling (to bound worst-case retry spacing for a
genuinely long-absent device).
Skills: language-specific-implementation, performance-optimization
Depends-on: [T1.1]
Status: direction confirmed by user; exact parameters open
Risk-hint: LOW

---

### SG2: Self-correcting reachability indicator on the paired-list page

#### Task T2.1: Chain probe → await-reconcile → re-probe in the paired-device indicator
Objective: `_PairedTvConnectionIndicator` (in `pairing_page_sections.dart`) becomes: probe the
current known host → on failure, await the page's own already-running reconciliation pass (made
awaited/shared instead of today's fire-and-forget `unawaited` call in `_scanDevices()`) → if this
device received a host update, re-probe the new host → grey ("not found right now") only if both
attempts fail. No automatic retry beyond this single chain — the next manual rescan remains the
retry trigger for this surface, matching the smaller scope this screen needs (per user: "for
discovery we only care to see the list; once we want to pair, that's when it has to be reliable").
Detail: One reconciliation pass must serve every indicator on the page (the existing per-scan
reconciliation already covers the whole saved-device list) — indicators must not each trigger
their own separate reconcile call, which would multiply scans per paired device. Does not depend on
SG3/SG4 — works against whatever `reconcile()` returns today.
Skills: language-specific-implementation, clean-code-solid, correctness-validation
Depends-on: []
Status: design agreed; diff not yet written
Risk-hint: MEDIUM — changes a widget lifecycle pattern (`ValueKey`/`scanCount`) shared across the
whole paired list

---

### SG3: Extend Android TV identity capture with a passive, connection-independent source

#### Task T3.1: Parse the `bt` mDNS TXT field during Android TV discovery
Objective: `mdns_device_discovery_service.dart` builds `androidtv-bt-<mac>` when the TV's
`_androidtvremote2._tcp` TXT record includes a `bt=` field; falls back to today's
`androidtv-<ip>` when absent — no regression for devices without it.
Detail: Confirmed against the `multicast_dns` package already in use (`ResourceRecordQuery.text`,
`TxtResourceRecord.text`) — no new dependency. TXT lookup runs concurrently with the existing
SRV/A lookups to avoid added scan latency. MAC normalized to lowercase at parse time for
consistent id strings across scans. Improves how often SG1/SG2's reconciliation succeeds for
Android TV; not a prerequisite for either (D-3).
Skills: language-specific-implementation, clean-code-solid, correctness-validation
Depends-on: []
Status: design + diff fully scoped in conversation; not yet written to a file
Risk-hint: LOW

#### Task T3.2: Verify `bt` presence on the reporting user's actual hardware
Objective: Confirm via `dns-sd`/`avahi-browse` from a LAN device whether the user's specific
Android TV advertises a `bt=` TXT field, to know whether T3.1 helps this device directly or
whether it remains on IP-fallback.
Detail: Purely informational — no code impact either way, since T3.1 degrades gracefully.
Skills: correctness-validation
Depends-on: []
Status: pending — requested from user, not yet answered
Risk-hint: LOW

---

### SG4: Ensure reconciliation is safe across a mixed identity-source population

#### Task T4.1: Add a certificate-confirmation gate before trusting a bt-based match
Objective: When reconciliation finds a candidate match via `bt`-derived id, confirm it against
the TV's existing stored certificate (already captured at pairing) before updating the saved
device's host — protecting against the demonstrated MAC-collision risk (D-4).
Detail: Exact mechanism not yet designed at the code level — needs to decide where the gate lives
(inside `DeviceReconciliationService.reconcile()`, or as a wrapping step in
`PairingPageData.reconcileDiscovery`) and how a failed confirmation should be surfaced (silently
skip vs. flag as a separate "possible duplicate" case).
Skills: correctness-validation, clean-code-solid, security
Depends-on: [T3.1]
Status: concept agreed; diff not yet scoped
Risk-hint: MEDIUM — touches core reconciliation matching logic

#### Task T4.2: Regression-check legacy IP-only matching path
Objective: Confirm devices with no `bt` and no cert-based id yet (still purely IP-derived) continue
to be handled by the existing legacy-rekey heuristic unchanged.
Detail: No new behavior — verification only, to ensure T3.1/T4.1 don't narrow what already works
for devices without a passive identity source.
Skills: correctness-validation, test-creation-strategy, regression-prevention
Depends-on: [T3.1, T4.1]
Status: not started
Risk-hint: LOW

---

## Open items (explicitly not settled — do not treat as agreed)

- D-2: whether app-fully-closed recovery is truly out of scope was never explicitly confirmed —
  see D-2 above.
- Roku's complete lack of any post-pairing identity re-derivation (see Problem #3) — no fix
  discussed; not resolved by SG1–SG4.
- T3.2: whether `bt` is actually present on the reporting user's hardware.
- T4.1: exact mechanism and location for the cert-confirmation gate.
- T1.2: wait-duration growth curve and cap.
- Exact numeric parameters used throughout this document (3 fast attempts, 5s cadence, 45s initial
  wait) were proposed during design discussion, not independently specified by the user as hard
  requirements — worth final confirmation once diffs are drafted.
- Whether T4.1's failed-confirmation case should be silent (fall back to no-match) or surfaced
  distinctly (e.g., a "possible duplicate device" signal) — not discussed.

---

## Done criteria (tentative)

- The remote/home page recovers from a transient port-level failure automatically, within one full
  cycle (fast phase + escalation + first wait), without requiring the user to reopen the app.
- The paired-list page's wifi icon reflects a freshly reconciled host within the same scan that
  found it, not requiring a second manual rescan.
- Both of the above work correctly today, against existing identity sources, independent of
  whether SG3/SG4 have landed yet.
- A previously-paired Android TV with `bt`-advertising firmware is reconciled correctly after an
  IP change, without requiring a live TLS connection to have succeeded during that same scan.
- A `bt`-based match is never used to update a saved device's host without cert confirmation
  succeeding first.
- Devices without `bt` (Roku, manually-added, non-advertising Android TV firmware) are unaffected
  — same behavior as today, no regression.
- `flutter analyze` clean; existing test suite green; new coverage added for the reconciliation
  mixed-identity-source path (T4.2) and the retry state machine (T1.1).
