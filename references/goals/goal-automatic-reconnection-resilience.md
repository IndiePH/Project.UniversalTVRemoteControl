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

### D-2: Out of scope — recovery while the app is fully closed
Confirmed with user: automatic reconnection only needs to work while the app is open. No
background mechanism (Android WorkManager, foreground service, etc.) is needed or wanted —
avoids the battery/OS-policy tradeoffs that would come with one.

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

### D-6: Home-page retry cycle repeats indefinitely; escalation stays flat per lap; wait duration grows exponentially, capped
Confirmed with user: the fast-phase and escalation-phase behavior stays identical on every lap
("flat") — same attempt count, same cadence, same single reconciliation pass. The wait period
between laps doubles each successive failed lap (45s → 90s → 180s → 300s, capped — see T1.2 for the
exact numbers and rationale), so a genuinely long-absent device stops being polled aggressively
without giving up recovery speed early in a disconnected streak. Growth resets back to the 45s base
whenever a fresh disconnected streak begins (a real connection succeeded, or the device/page
resubscribed) or the user taps retry-now — neither should inherit escalation from unrelated prior
failures.

### D-7: `DeviceIdentityRegistry` is resolved via GetIt at the point of use, not threaded through page constructors
Confirmed with user (raised as a direct challenge to the original T1.1 draft, which proposed adding
an `identityRegistry` constructor parameter to `RemoteHomePage`): `DeviceIdentityRegistry` is not a
second store of identity — `TvDevice.id`, persisted via `DeviceRepository`, remains the single
source of truth. The registry is only a session-scoped, in-memory `host → stableId` lookup cache
that lets transport/secret-store code resolve a dialed host back to its stable id without an async
repository read. `PairingPage`'s only production call site (`remote_home_actions.dart`) already
resolves it this way — `sl.isRegistered<DeviceIdentityRegistry>() ? sl<DeviceIdentityRegistry>() :
null` — rather than having it passed down from further up the widget tree. `RemoteHomePage` follows
the same precedent: no constructor change, no test call-site changes: the retry controller (T1.1)
resolves it internally via GetIt when it needs to call `PairingPageData.reconcileDiscovery`.

---

## Sub-goals and tasks

### SG1: Automatic, self-recovering reconnection on the remote/home page

#### Task T1.1: Implement the repeating fast → escalate → wait cycle
Objective: `remote_home_page.dart`'s connection retry becomes: fast phase (~3 attempts at 5s) →
escalation (one discovery+reconcile pass, then a connect attempt) → on continued failure, a single
wait period displayed as "Connection error... retrying in Xs [retry-now icon]" with a live
per-second countdown → on timeout or manual tap, loop back to the fast phase. Repeats indefinitely
while the page is open and disconnected.

Concrete approach (finalized):
- New `ReconnectionRetryController` (own file, not inlined into `_RemoteHomePageState`, per
  clean-code-solid SRP) exposes a `ValueListenable<ReconnectionRetryState?>` — `null` means idle;
  otherwise `{phase: fastRetry|escalating|waiting, waitSecondsRemaining}`.
- `start(device)`: begins the fast phase. Deliberately does **not** fire an immediate connect on
  entry — only on each 5s tick — so it doesn't add an extra connect() call on top of the one
  `_subscribeConnectionState` already fires directly on subscribe (preserves today's exact
  connect-call-count behavior, verified against every existing `Duration(seconds: 5)` assertion in
  `test/widget_test.dart`; no test rewrites needed).
- Every attempt (fast-phase tick or escalation) is gated by an injected `canAttemptNow()` callback
  (`mounted && ModalRoute.of(context)?.isCurrent == true`), matching today's "skip while another
  route is on top" behavior exactly — a blocked tick is skipped, not counted, so progress resumes
  cleanly once unblocked.
- On the 3rd fast attempt, runs escalation: `PairingPageData.discoverDevices` +
  `PairingPageData.reconcileDiscovery` (identical call already used by the pairing page's own scan
  reconciliation, per D-1 — no new discovery/reconciliation plumbing). `DeviceIdentityRegistry` is
  resolved internally via GetIt at this point, per D-7, not passed into the controller from
  `RemoteHomePage`'s constructor.
- **Device-refresh gap (found while designing this, now closed):** `reconcile()` only updates the
  in-memory `DeviceIdentityRegistry` and returns a diff; `reconcileDiscovery` is what persists the
  new host via `deviceRepository.saveDevice()`. Neither of those updates the `TvDevice` object the
  page itself is holding (`_activeDevice`) or the one the controller is mid-cycle with — so without
  an explicit fix, a successful reconnect right after a host change would still dial the stale IP
  for the next command. Fix: after `reconcileDiscovery` returns, the controller re-reads
  `deviceRepository.getSavedDevices()`, finds the entry matching its device's `id`, and if the host
  differs, (a) uses the refreshed device for its own next `connect()` call, and (b) invokes a new
  `onDeviceUpdated(TvDevice)` callback so `_RemoteHomePageState` can `setState(() => _activeDevice =
  device)`. This is the mechanism that actually closes the loop from "reconciliation found a new
  host" to "the page is actually talking to that host."
- `retryNow()`: cancels the pending wait timer, fires a connect attempt **immediately** (not on the
  next tick — this is a distinct code path from `start()`, so it doesn't affect the cold-start
  connect-count tests above), then resumes the fast phase from attempt 1. Satisfies "must not just
  reset the clock and wait out another full interval."
- `stop()`/`dispose()`: cancels any active timer; wired into `_RemoteHomePageState.dispose()` and
  everywhere `_stopConnectionRetry()` is called today (unauthorized state, paused lifecycle, device
  switch).
- No `RemoteHomePage` constructor changes and no `test/widget_test.dart` call-site changes required
  anywhere in this design.

Skills: language-specific-implementation, clean-code-solid, framework-mastery
Depends-on: []
Status: implemented (`ReconnectionRetryController` + `RemoteHomePage`/`RemoteHomeStatusPanel`
wiring) and covered by 9 unit tests in `reconnection_retry_controller_test.dart` (fast/escalate/wait
cycle, `retryNow` immediacy, `canAttemptNow` gating, the device-refresh gap fix, and escalation
failure resilience). `flutter analyze` clean; full suite green (754/754). Not yet re-verified against
real hardware.
Risk-hint: MEDIUM — new state machine in a heavily-used screen

#### Task T1.2: Grow the wait duration across successive laps
Objective: The wait period (T1.1) increases on each successive lap of the outer cycle rather than
staying at a fixed duration indefinitely, while the fast phase and escalation phase stay identical
every lap.

Confirmed approach: exponential growth with a cap (chosen over a simpler linear-step alternative and
a coarser single-step-up alternative, both presented and rejected in favor of this one) — the
standard shape for this exact problem (matches gRPC/AWS-SDK/Socket.IO-style reconnection backoff).
- Base (lap 1) wait: 45s — unchanged from T1.1's original fixed value.
- Growth: ×2 per successive failed lap (45s → 90s → 180s → 300s...).
- Cap: 5 minutes — the wait never grows past this however many laps fail in a row, bounding
  worst-case retry spacing for a genuinely long-absent device while still being a dramatic
  improvement over the hours-long, fully-manual recovery from the triggering incident.
- Reset conditions (both confirmed with user): growth resets back to the 45s base when (a) `start()`
  begins a fresh disconnected streak (i.e. a real connection succeeded since the last failure, or the
  page/device resubscribed), and (b) the user taps retry-now — a manual retry should get the fastest
  path back, not inherit escalation from automatic failures earlier in the same streak.

Skills: language-specific-implementation, performance-optimization, tradeoff-communication
Depends-on: [T1.1]
Status: implemented (`ReconnectionRetryController.waitGrowthFactor`/`waitCap`, reset in `start()` and
`retryNow()`) and covered by 3 additional unit tests (growth-and-cap across 5 laps, reset-on-retryNow,
reset-on-fresh-start). `flutter analyze` clean; full suite green (757/757).
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
SG3/SG4 — works against whatever `reconcile()` returns today. When the reconciliation pass completes
without changing a device's host (including Roku, which has no way to change it at all — see
Problem #3), the indicator does **not** re-probe that same address a second time (confirmed with
user): a same-host retry is a wasted network call, and a genuine same-host flake self-corrects on
the next manual rescan anyway, matching this screen's already-agreed lower reliability bar.

A real timing gotcha was found and fixed while implementing this: `scanCount` (part of each row's
`ValueKey`, which is what forces `_PairedTvConnectionIndicator` to re-run its probe) used to bump at
the very start of `_scanDevices()`, before discovery or reconciliation existed. Threading the shared
reconciliation `Future` into an indicator built at that moment would hand it a stale/null value
forever, since a `StatefulWidget` only reads its constructor args once, in `initState`. Fixed by
moving `scanCount`'s bump into the same `setState` that sets `discoveredDevices` — i.e. indicators
are (re)created only once discovery has resolved and the real reconciliation `Future` already exists.

Skills: language-specific-implementation, clean-code-solid, correctness-validation
Depends-on: []
Status: implemented (`_PairedTvConnectionIndicator`'s probe → await-shared-reconcile → conditional
re-probe chain, `_pendingReconcile` shared field on `_PairingPageState`, the `scanCount` timing fix)
and covered by 5 new tests: 3 widget tests through `PairingPage` (reprobe-and-succeed after a host
change, skip-reprobe when the host is unchanged, two-devices-off-one-shared-pass) plus 2 tests
constructing `PairedTvListItem` directly (bypassing `PairingPage`, since `reconcileDiscovery`'s own
internal try/catches make it impractical to force a real throw through the page) to exercise the
indicator's defensive catch around a throwing shared reconciliation pass. `flutter analyze` clean;
full suite green (762/762), including all 4 pre-existing connection-indicator tests unchanged.
Risk-hint: MEDIUM — changes a widget lifecycle pattern (`ValueKey`/`scanCount`) shared across the
whole paired list

---

### SG3: Extend Android TV identity capture with a passive, connection-independent source

#### Task T3.1: Parse the `bt` mDNS TXT field during Android TV discovery
Objective: `mdns_device_discovery_service.dart` builds `androidtv-bt-<mac>` when the TV's
`_androidtvremote2._tcp` TXT record includes a `bt=` field; falls back to today's
`androidtv-<ip>` when absent — no regression for devices without it.
Detail: Confirmed against the `multicast_dns` package already in use (`ResourceRecordQuery.text`,
`TxtResourceRecord.text`) — no new dependency; re-verified directly against the pinned 0.3.3
package source (not just prior research) before implementing, including how it joins multiple
TXT strings with `\n` via `StringBuffer.writeln` — confirms `rawText.split('\n')` is the correct
parse approach. TXT lookup runs concurrently with the existing SRV/A lookups (started before the
SRV `await for`, not after) to avoid added scan latency. MAC normalized to lowercase at parse time
for consistent id strings across scans. Improves how often SG1/SG2's reconciliation succeeds for
Android TV; not a prerequisite for either (D-3).

The `bt=` parsing logic was extracted into its own small utility,
`AndroidTvBluetoothMacTxtParser` (new file), rather than left as a private method on
`MdnsDeviceDiscoveryService` — that class has zero existing tests and no seam to inject a fake
`MDnsClient` (real network I/O, presumably validated manually against real devices today), so
extracting the pure, deterministic parsing piece was what actually made this task unit-testable at
all, not just a style preference.

Skills: language-specific-implementation, clean-code-solid, correctness-validation
Depends-on: []
Status: implemented (`AndroidTvBluetoothMacTxtParser` + `MdnsDeviceDiscoveryService`'s concurrent
TXT lookup) and covered by 8 unit tests on the parser (single/multiple entries, absent, empty
value, malformed line, whitespace, case normalization). `flutter analyze` clean; full suite green
(770/770). The discovery service's own orchestration (the concurrent-lookup wiring itself) is
unverified by an automated test, consistent with the rest of that file's pre-existing untested
status — flagged, not silently left unmentioned.
Risk-hint: LOW

#### Task T3.2: (Dropped as a requirement) `bt` presence is unknown and unverifiable in general
Not a blocking task. Whether `bt` is present on any given device — the reporting user's or
anyone else's — is unknown and expected to vary; this is exactly why T3.1 falls back to the
IP-derived id and why reconciliation (SG4) must handle a mixed population regardless. No
verification step is required before proceeding with T3.1.
Skills: —
Depends-on: []
Status: not applicable
Risk-hint: —

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

- Roku's complete lack of any post-pairing identity re-derivation (see Problem #3) — no fix
  discussed; left open for now, not resolved by SG1–SG4.
- T4.1: exact mechanism and location for the cert-confirmation gate.
- Exact numeric parameters used throughout this document (3 fast attempts, 5s cadence) were proposed
  during design discussion, not independently specified by the user as hard requirements — worth
  final confirmation if they prove wrong in practice. T1.2's own numbers (45s base, ×2, 5m cap) are
  now confirmed, not open.
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
