# Goal: Automatic Reconnection Resilience

**Status:** TENTATIVE — baseline breakdown only, **NOT FINALIZED**. To be updated with proposed
diffs and re-confirmed before any code is written.
**Branch:** `fix/reconnection` (current)
**Depends on:** `references/goals/goal-persistent-device-identity.md` (Phases 0–5, shipped) — this
goal treats that work as a completed foundation and does not reopen it. It extends identity
coverage and adds the automation layer that foundation does not itself provide.
**Origin:** Surfaced while diagnosing a real incident — a paired Android TV failed to reconnect
after two router restarts, despite being network-reachable (Wi-Fi + internet) the entire time.
Confirmed unreachable for the ~10-15 minutes of active troubleshooting; it then worked again when
the app was reopened hours later. The multi-hour figure is elapsed time until the next check, not
confirmed continuous downtime — corrected here after initially overstating it as "hours of
confirmed unreachability," which the user caught.

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
   successful TLS handshake to the TV's remote-control port (6466). That is the same port confirmed
   unreachable during the ~10-15 minutes of active troubleshooting in the triggering incident, even
   while the TV remained reachable via Wi-Fi/mDNS/internet that whole time (see Origin above — the
   device was already cert-identified going into the incident; this was never a legacy-id problem).
   This narrows the odds that even an automatic reconciliation pass (once #1 is fixed) succeeds on
   a given attempt for this device class.

3. **Identity source availability is not guaranteed and not uniform across devices.** Some
   Android TV firmware may not advertise a Bluetooth MAC via mDNS at all (unverified either way
   for the reporting user's own hardware) — SG5 covers this case via a certificate-based fallback
   that yields the *same* `androidtv-<mac>` id (see D-8), not a separate scheme. What can still
   differ per-scan is only whether a MAC is obtainable via *either* channel this moment (both are
   channel/reachability-dependent, not device-permanent) — a device can still land on a lesser
   `androidtv-<sha256>` or `androidtv-<ip>` id on a scan where neither works. Manually-added devices
   of any brand have no passive identity source at all today. Reconciliation must work correctly
   across this mixed population of *format*, not assume any one format is universally present on any
   given scan (see revised SG4).

   **Roku is a sharper case than the above implies, and is not addressed by any task below.**
   Unlike Android TV, Roku's discovery layer never attempts to re-derive its stable id (the ECP
   serial number, captured once at pairing) on any later scan — there is no enrichment step for
   Roku at all, fragile or otherwise. This means a Roku device that changes IP after pairing
   cannot be matched by reconciliation even once SG1/SG2 make it run automatically, because the
   main matching pass requires the *freshly discovered* device to also carry a stable id, and
   Roku's discovery never produces one. No fix for this was discussed or designed in this
   conversation — flagged here as a known, currently out-of-scope gap, not something SG1–SG5
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
automatically (SG1, SG2 below) — it doesn't depend on or wait for the identity work (SG3, SG5, SG4).
Those improve the *odds* reconciliation succeeds for Android TV specifically; they are not
prerequisites for SG1/SG2, and SG1/SG2 should not be blocked on them.

### D-4: `bt`-derived identity requires cert confirmation before being trusted
A real-world collision case was found (Home Assistant GitHub issue #134867 — two distinct TiVo
Stream 4K units, made by SEI Robotics, reporting the identical Bluetooth MAC). `bt` is treated as
a fast *candidate-finding* signal, not sufficient on its own to merge two device records — the
existing cert-based identity must confirm the match first.

> **Superseded by D-8/D-11**: "cert confirms bt" assumed they were independent signals. They're now
> known to read the same underlying MAC, so cert can no longer independently confirm a `bt` match —
> the collision risk this decision was meant to address is still real, but no longer has this
> mitigation. See D-11 and the revised SG4/T4.3.

### D-5: Reconciliation must handle bt-ids, cert-ids, and legacy IP-ids side by side
Because `bt` availability varies by device/firmware (unverified, per-device), the discovery and
reconciliation logic must not assume any single identity source is universally present — a
network may simultaneously contain devices identified by any of the three schemes.

> **Refined by D-8**: "bt-ids" and "cert-ids" are no longer two schemes — both normalize to
> `androidtv-<mac>` (see SG5). The side-by-side handling this decision calls for now applies to
> *format* (mac / hash-fallback / legacy-ip), not to competing identity sources.

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

### D-8: Android TV's stable id unifies around a single Bluetooth MAC, not two competing schemes
Superseded understanding, reached through extended re-analysis after T3.1 shipped (see SG5): `bt`
(from mDNS) and "cert-id" were never meant to be two independent identity schemes needing
cross-confirmation. Verified directly against a mature reference implementation
(`tronikos/androidtvremote2`) and Home Assistant's production `androidtv_remote` integration source:
the Android TV Remote v2 pairing certificate embeds the device's Bluetooth MAC address in its
subject field (e.g. `CN=atvremote/darcy/darcy/SHIELD Android TV/XX:XX:XX:XX:XX:XX`), extractable via
a plain, unpaired connection — and Home Assistant treats a MAC read from `bt` (mDNS) and a MAC read
from the certificate as the *literal same identifier*, both normalized through `format_mac()` into
the same `unique_id`. So there is one underlying identity (the Bluetooth MAC), reachable through two
channels of differing cost/trust, not two schemes to reconcile between.

**Naming, confirmed with user:** the id format is `androidtv-<mac>` regardless of which channel
supplied the MAC — no `-bt` tag distinguishing the source. Initially this was going to be left as
`androidtv-bt-<mac>` in T3.1's shipped code as "not worth a rename-only diff" — but that reasoning
didn't hold up against Problem #3's own claim that `bt` availability can vary per scan for the same
device (not device-permanent): a device could get `androidtv-bt-<mac>` on one scan and
`androidtv-<mac>` (via T5.1's cert fallback) on another, producing two different id strings for one
physical device and silently breaking the exact-match reconciliation D-8/T4.1(revised) relies on.
Fixed: `mdns_device_discovery_service.dart` now builds plain `androidtv-<mac>`, no `-bt` segment.

**Why this is different from a WiFi MAC (a real, rejected alternative, per user's own correct
caution):** Android randomizes WiFi MACs per-network by default since Android 10, specifically for
privacy — the "About phone" screen showing a fixed value is informational only, not what's actually
used on the wire. The Bluetooth MAC used here is a *different* subsystem, deliberately exposed
non-randomized via both `bt` and the certificate specifically so companion apps can persistently
recognize the device — confirmed via the same sources above treating it as stable by design, not
merely observed-to-be-stable.

**Serial number investigated and ruled out:** the Settings → About page's serial number is local-only
— neither the `_androidtvremote2._tcp` mDNS TXT record (Home Assistant's integration reads only
`bt` from it) nor the pairing certificate's subject (only name/model-codename + MAC) exposes a
per-unit serial over this protocol. Not usable via any channel this app has access to.

### D-9: The "already-recognized" gate on cert-based enrichment is retired; the real rationale was consent, not MITM defense
`CompositeDeviceDiscoveryService._enrichAndroidTvIdentity` previously only upgraded a discovered
device's id to a cert-derived value when `AndroidTvCertificateStore.hasStoredServerCertificate`
already recognized that certificate (i.e., only for devices paired before). Traced this gate back to
its origin (`d80600771`/`026f4cd19`, Phase 1 of the persistent-identity work) — no documented
attack it defends against; its own code comment frames it as "prevents an unpaired TV from being
treated as a known device just because port 6466 is reachable."

Re-examined and refined with user: this is **not** meaningfully a MITM defense — TLS's own
private-key-possession requirement already prevents an attacker from convincingly presenting an
already-known device's exact certificate without having compromised that device. The actual concern
is **consent**: pairing requires the TV to display a PIN a human must read and enter, which is the
real "yes, this is my TV" moment; mere network reachability proves nothing about that.

That consent concern does not apply to using a MAC as a *discovery-time label* for an unpaired
device — "is this device saved/paired" is already a separate check elsewhere (`savedDeviceIds`),
unaffected by which id scheme is used. It also does not introduce any new connection: the live TLS
probe already runs, unconditionally, against every discovered Android TV on every scan today,
regardless of this gate — the gate only ever controlled whether the *result* was used. Confirmed with
user: retire the gate; extract and use the MAC unconditionally (see SG5/T5.1).
`hasStoredServerCertificate` becomes unused once nothing gates on it — remove rather than leave as
dead code.

### D-10: `bt` is connectionless/broadcast-like; a cert read is a targeted connection to a control-relevant port — this is what actually distinguishes them, not "who asks first"
Clarified with user: both `bt` (mDNS) and a cert read are technically "active" in the sense that our
code sends a request rather than passively overhearing something — that distinction doesn't explain
why one needed a consent gate and the other didn't. The real distinction: `bt` is a connectionless
UDP multicast query/response, the same mechanism used for every other piece of mDNS discovery data
(PTR, SRV, hostname) — no different in kind from how SSDP brands broadcast their UDN, safe to trust
unconditionally, and already trusted that way with no gate. A cert read requires opening an actual
TCP+TLS connection to the device's specific remote-control port — the same port used for real
remote-control sessions once paired — a targeted, present interaction with that specific device,
which is why it was the one signal that warranted the consent-aware caution addressed in D-9.

### D-11: MAC-collision risk is real but not a "forgery" — and is no longer mitigated by independent-signal confirmation
A MAC address is intended to have UUID-like uniqueness (IEEE allocates OUI blocks to manufacturers,
who are supposed to assign a distinct value per unit) but, unlike a properly-random 128-bit UUID,
its uniqueness depends entirely on the manufacturer's own provisioning process getting that right.
The documented real-world case (Home Assistant GitHub issue #134867) was SEI Robotics — a white-label
hardware maker supplying multiple different branded products — apparently duplicating a MAC across
units via a flashing/provisioning defect, not a deliberate attack.

This risk **does not go away** under the D-8 unification, and in fact loses the mitigation originally
imagined for it: the original SG4/T4.1 design assumed `bt` and cert-id were independent signals that
could corroborate each other (two different subsystems on the TV agreeing). Now that both are known
to read the *same* underlying MAC, a colliding device would report the identical (wrong) value
through both channels — there is no second, independent source left to catch it.

**Resolved with user:** accept this as a rare, bounded, unmitigated residual risk rather than build a
new detection mechanism. Reasoning: MAC uniqueness is a manufacturer-side contract (IEEE allocates
OUI blocks per manufacturer, who are supposed to assign a distinct value per unit) — a collision is
their provisioning defect, not something this app can meaningfully re-verify without reintroducing
the exact independent-signal cross-check D-8 just established as unnecessary complexity for the
common case. Home Assistant's production `androidtv_remote` integration — the same reference source
verified for D-8/D-9 — has this identical exposure (a MAC from either `bt` or the cert becomes
`unique_id` with no corroboration step) and does not address it either; a defect this rare going
unmitigated in a mature, widely-deployed reference implementation is itself evidence the real-world
cost doesn't currently justify the engineering cost of a fix. See T4.3.

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
SG3/SG5/SG4 — works against whatever `reconcile()` returns today. When the reconciliation pass completes
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

> Now understood as one half of a unified scheme, not a standalone identity source — see D-8. `bt`
> is the free/preferred channel; SG5 adds the fallback channel (a live cert read) for devices that
> don't advertise `bt`, producing the *same* `androidtv-<mac>` id format either way.

#### Task T3.1: Parse the `bt` mDNS TXT field during Android TV discovery
Objective: `mdns_device_discovery_service.dart` builds `androidtv-<mac>` when the TV's
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
value, malformed line, whitespace, case normalization). `flutter analyze` clean. The discovery
service's own orchestration (the concurrent-lookup wiring itself) is unverified by an automated
test, consistent with the rest of that file's pre-existing untested status — flagged, not silently
left unmentioned.

**Follow-up fix (found during a post-doc-revision review, after D-8):** the shipped id format was
originally `androidtv-bt-<mac>`, not plain `androidtv-<mac>` as D-8 assumed — an inconsistency that
would have broken exact-match reconciliation between the `bt` and cert-fallback (T5.1) channels for
the same device across scans. Fixed directly (one-line change, `mdns_device_discovery_service.dart`):
now builds `androidtv-<mac>` with no `-bt` segment. Re-verified: `flutter analyze` clean, all 474
tests in `test/lib/remote_control/data/` passing.
Risk-hint: LOW

#### Task T3.2: (Dropped as a requirement) `bt` presence is unknown and unverifiable in general
Not a blocking task. Whether `bt` is present on any given device — the reporting user's or
anyone else's — is unknown and expected to vary; this is exactly why T3.1 falls back to the
IP-derived id and why SG5/SG4 must handle a mixed population regardless. No verification step is
required before proceeding with T3.1.
Skills: —
Depends-on: []
Status: not applicable
Risk-hint: —

---

### SG4: Ensure reconciliation is safe across a mixed identity-source population

> **Substantially re-scoped, not just updated**, after D-8. The original premise — cert
> independently confirms a `bt`-based match — no longer holds, because `bt` and the cert-derived MAC
> are now understood to be reads of the *same* value, not independent signals. The cross-scheme
> matching problem T4.1 was built to solve is resolved for free once SG3/SG5 both normalize to
> `androidtv-<mac>`: today's existing exact-id-match `reconcile()` just works, no new code needed for
> that part. What's left is different from the original task, and the collision risk it was also
> meant to address (D-4) is *harder*, not solved — accepted instead as residual risk, see D-11/T4.3.

> **Re-scoped a second time, after directly re-reading `device_reconciliation_service.dart` and
> `android_tv_tcp_transport_client.dart`, and walking through which of the three id formats
> (`mac`/`sha256`/`ip`) actually needs new correlation code.**
>
> - **`mac`** needs nothing new — two independent channels (`bt`, cert-subject parse) both land on
>   the identical string, so exact-match `reconcile()` already handles it.
> - **`sha256`** also needs nothing new, *for devices that consistently land there* — cert-subject
>   parseability is a fixed trait of a device's firmware/cert, not something that flips scan to
>   scan, so a device that can't be MAC-parsed will consistently fall to the same `sha256` on every
>   scan (pairing included), and exact-match already handles that too.
> - **Pre-existing paired devices saved under the *old* `androidtv-<sha256>` scheme** (from before
>   this work existed) are a real, currently-live mismatch once T3.1/T5.1 start producing
>   `androidtv-<mac>` for the same device — but **deliberately out of scope, decided with user**:
>   fixing it would mean running a host+brand correlation check on *every* scan for as long as any
>   `sha256`-saved device exists, not a one-time fix, for a population that shrinks on its own as
>   people naturally re-pair. Accepted: those devices need one manual re-pair after this work lands,
>   same resolution as T4.3's accepted-risk precedent.
> - **`ip`** is the one genuinely per-scan-flaky case — "nothing reachable this scan" is transient
>   network state, not a stable device trait, so it can't self-correct the way the other two do. This
>   is the *only* case T4.1 below actually needs to handle, and it's exactly the original triggering
>   incident's situation (saved `androidtv-<mac>`, discovered `androidtv-<ip>` because neither `bt`
>   nor a live cert connection worked this scan).
>
> **Dropped entirely, after the host+brand mechanism above was found to be broken by construction.**
> The proposed T4.1 match required the discovered device's host to equal the saved device's host —
> but the whole point of this task was handling an IP *change*, which by definition means those hosts
> differ. Matching on "same host" can only ever fire in the case where nothing needs updating (a
> no-op); it cannot fire in the case it was meant to solve. Once host is removed from the match, the
> only thing left to correlate on is much weaker — "exactly one saved `androidtv-<mac>` device with no
> exact match this scan, and exactly one discovered `androidtv-<ip>` device this scan, anywhere on the
> network" — which has a real misfire risk (could merge two different physical TVs for a user who owns
> more than one) with no host anchor to bound it. There is no safe middle version. Decided with user:
> don't build either — accept this scenario (IP changed at the same moment neither `bt` nor a live
> cert connection worked) as a rare, self-healing gap, same treatment as T4.3 and the sha→mac
> migration case. SG1's automatic retry means a later scan very likely recovers the MAC and reconciles
> normally via exact match; the cost of not building this is at most a delayed reconnect, not a
> permanently broken one.

#### Task T4.1: Correlate a saved `androidtv-<mac>` device against a same-scan `androidtv-<ip>` discovery — dropped
Not built. See the dropped-entirely note above: the only mechanism that could actually fire (removing
host from the match) carries real misfire risk with no offsetting benefit once SG1's automatic retry
is accounted for. No task tracking this further; logged here so it isn't rediscovered and rebuilt
without re-deriving why it was rejected.
Skills: correctness-validation, risk-analysis
Depends-on: []
Status: dropped — accepted as a rare, self-healing gap; no further work planned
Risk-hint: —

#### Task T4.2: Regression-check legacy IP-only matching path — moot
Was verification-only for T4.1's new pass. Since T4.1 was dropped, there is no new pass to regression-
check; the existing legacy-rekey heuristic is untouched by this goal.
Skills: —
Depends-on: []
Status: not applicable
Risk-hint: —

#### Task T4.3: MAC-collision residual risk — accepted, not mitigated
Per D-11: the collision risk D-4 identified no longer has the independent-signal mitigation the
original design assumed. Resolved with user: accept it as a rare, bounded residual risk rather than
build a new detection mechanism — MAC uniqueness is the manufacturer's responsibility (IEEE OUI
allocation), not something this app can independently re-verify, and Home Assistant's own production
integration carries the same exposure with no mitigation (see D-11). No implementation follows from
this task — it's a documented, accepted limitation, not a build item.
Skills: security, risk-analysis
Depends-on: []
Status: resolved — accepted as an inherent, unmitigated risk; no further work planned
Risk-hint: LOW (accepted residual risk, not actively mitigated)

---

### SG5: Extend the unified MAC-based id to Android TVs that don't advertise `bt`

Objective, added after T3.1 shipped (see D-8): devices whose firmware doesn't advertise `bt` via
mDNS should still get the same `androidtv-<mac>` id — sourced from the certificate's embedded MAC
instead — rather than falling all the way back to an IP-derived id whenever they're merely
unreachable via `bt` but otherwise connectable.

#### Task T5.1: Extract the MAC from the pairing certificate's subject as the primary cert-derived id, demoting the whole-DER hash to a fallback
Objective: `CompositeDeviceDiscoveryService`'s Android TV enrichment step stops treating the whole-DER
hash (`AndroidTvCertificateStore.stableIdFromServerCertificate`) as the primary result of a live cert
read. Instead it first parses the certificate's subject field for the embedded Bluetooth MAC (per
D-8's confirmed format, e.g. `CN=.../SHIELD Android TV/XX:XX:XX:XX:XX:XX`), producing `androidtv-<mac>`
— the same format `bt` already produces. Runs **unconditionally** for every discovered Android TV,
paired or not — the `hasStoredServerCertificate`/"already recognized" gate is retired per D-9.

This leaves three id formats in play, in descending order of how much a device gets to keep of its
identity across scans (confirmed with user):
- `androidtv-<mac>` — the normal case, MAC available via `bt` or a live cert-subject read.
- `androidtv-<sha256>` — the rare fallback below, only reached if subject-MAC parsing fails on some
  OEM's differently-formatted certificate.
- `androidtv-<ip>` — no MAC available at all and no live connection possible (the original
  triggering incident's exact situation).

Detail: Use `basic_utils`'s `X509Utils` (already a direct dependency, used elsewhere in
`android_tv_certificate_store.dart` for cert generation) to parse the subject rather than hand-rolled
ASN.1 RDN parsing. Different OEMs format the subject differently (confirmed two real, differently-shaped
examples from a mature reference implementation: NVIDIA Shield vs. Nexus Player) — parsing must
handle both known shapes and must not throw on an unrecognized one.
**Defensive fallback (confirmed with user):** if MAC extraction from the subject fails for any
reason, fall back to today's existing whole-DER-hash cert-id (`androidtv-<sha256>`) rather than
crashing or dropping straight to an IP-derived id — `stableIdFromServerCertificate` is kept for this,
not removed. Documented inline as unlikely but must-not-crash; also logged as its own item in
`references/tech-debt-list.md` to revisit whether this fallback is ever actually exercised in
practice, once real-device coverage exists.
**Consequence, not additional work:** this also fully resolves a bug found while designing T4.1
(now moot) — `BrandRoutedRemoteCommandService.preparePairing`'s ternary discarding a freshly-read
cert id in favor of an already-"stable" `bt` id at first-time pairing. Once both sources normalize to
the identical `androidtv-<mac>` string for the same physical device, there is nothing left to
discard; no fix to `preparePairing` is needed.
Also includes a related, small addition found while implementing: `CompositeDeviceDiscoveryService`
skips the live cert probe entirely when discovery already produced a `bt`-derived mac this scan
(confirmed safe — the pairing flow independently re-stores its own cert on success, so this doesn't
starve anything), and the identical mac-first-then-sha logic is applied to
`AndroidTvCertificateStore.stableIdForHost` (the pairing-time lookup) too, not just the discovery-time
probe — otherwise a brand-new pairing could still land on a `sha256` id.

Ported the MAC-extraction algorithm directly from `tronikos/androidtvremote2`'s actual source (fetched
and re-verified, not just summarized from earlier research): the MAC is the last `/`-separated segment
of the certificate subject's Common Name (`dnQualifier` carries the device name only, never the MAC).
Added one deviation from the reference: a MAC-shape validation on the extracted value before accepting
it, since the reference trusts it blindly for a display-only use, whereas this app exact-matches on it.

Skills: language-specific-implementation, clean-code-solid, security, correctness-validation
Depends-on: [T3.1]
Status: implemented (`AndroidTvCertSubjectMacParser`, `AndroidTvCertificateStore.stableIdFromDer`,
the retired `hasStoredServerCertificate` gate, and the discovery-time skip-if-already-stable check)
and covered by 11 new unit tests (parser: Shield/Nexus-shaped CNs, no-MAC, malformed/empty DER;
`stableIdFromDer`: mac-preferred and sha-fallback; composite discovery: skip-probe-when-already-stable)
using real synthetic certificates built via `basic_utils`, not mocks. `flutter analyze` clean; full
suite green (779/779). Committed: `bdfc452` (docs), `f5e7076` (code).
Risk-hint: MEDIUM — changes what a live-reachable, previously-unpaired Android TV's discovery-time id
looks like; touches `AndroidTvCertificateStore` and the enrichment path every scan already runs

#### Task T5.2: Migrate pre-existing `androidtv-<sha256>`-saved devices onto `androidtv-<mac>` — implemented, as a temporary shim

**Status: IMPLEMENTED**, after being dropped once and reopened. Objective: a device already saved
under the old whole-cert-hash scheme migrates onto the new `androidtv-<mac>` id automatically,
without requiring the user to manually re-pair.

**History — three problems found, two resolved, one accepted as a bounded, temporary cost:**
- **Correctness risk** (migrating trusts `AndroidTvCertSubjectMacParser`'s extraction, verified
  against only two device shapes — NVIDIA Shield, Nexus Player): **not eliminated, but accepted as
  bounded and temporary.** A wrong extraction settles into a wrong-but-*stable* id (the parser is a
  pure function of unchanging cert bytes) rather than a repeatedly-broken one — a data-integrity
  concern, not the "permanently breaks a working device" regression originally feared. Time-boxing
  the whole feature (below) bounds how long this exposure exists at all.
- **Plumbing** (carrying a cert hash from enrichment to a saved-record lookup without polluting
  `TvDevice`): resolved by **not** threading anything through `reconcile()`. The migration logic is
  fully self-contained (`AndroidTvLegacySha256IdMigrator`), makes its own connection, and touches
  only `DeviceRepository` directly.
- **Reach** (`CompositeDeviceDiscoveryService`'s skip-probe optimization means no cert connection is
  made for a device that already has a `bt`-derived id, so a mechanism living inside that path could
  never reach most affected devices): resolved by **not living inside that path at all.** The
  migrator runs as a fully independent step, making its own connection regardless of whether the
  device already has a `bt`-derived id this scan — deliberately paying for a connection T5.1's own
  optimization would otherwise skip. Accepted as a small, bounded cost (typically 1-3 devices per
  scan, cheap local-LAN TLS handshakes, scans not continuous) specifically because it's temporary.

**Design, confirmed with user:**
```
for each android tv in the discovered list this scan:
    connect and get its cert (independently of whatever _enrichAndroidTvIdentity already did)
    sha = hash(its cert)
    saved = find saved device where id == 'androidtv-' + sha
    if saved found:
        mac = parse mac from its cert
        if mac found:
            saved.id = 'androidtv-' + mac      # migrate
```
Implemented as `AndroidTvLegacySha256IdMigrator`
(`lib/remote_control/data/adapters/android_tv/android_tv_legacy_sha256_id_migrator.dart`) — zero
footprint on the permanent T5.1 code (`_enrichAndroidTvIdentity` is unmodified), one call site in
`PairingPageData.reconcileDiscovery` (fire-and-forget, `isRegistered`-guarded so it degrades to a
no-op wherever `AndroidTvCertificateStore` isn't in the DI graph), gated by a single `const bool
enabled` kill switch.

**Explicitly temporary — not permanent code.** Logged in `references/tech-debt-list.md` with a
removal deadline (~2026-11-10) and exit criteria: delete the file, its test, and its one call site
once `enabled` has been `false` for a full release or the deadline passes, whichever comes first.
Removal is scheduled, not conditional on whether problems show up first.

Skills: correctness-validation, clean-code-solid, security, risk-analysis, migration-strategy,
technical-debt-management
Depends-on: [T5.1]
Status: implemented — `AndroidTvLegacySha256IdMigrator` + 4 unit tests covering the pure
filtering/guard logic (the live-connection path is untested, consistent with this codebase's
existing tech debt for the same kind of code, per `discoverStableIdAtHost`). `flutter analyze`
clean; full suite green (783/783). Committed: `4f998a2` (feature), `e49901c`/`3ce1cb1` (doc-comment
follow-ups).
Risk-hint: MEDIUM — writes to saved device records for a population that currently works correctly,
mitigated by the correctness-risk analysis above and the fixed removal date

> **Ordering note (moot):** this originally debated implementation order between SG4 and SG5. Moot now
> that SG4's T4.1/T4.2 are dropped entirely (see SG4) — SG5/T5.1 is the only sub-goal in this section
> pair with any code, and it has already shipped. SG5 appears after SG4 in this document purely because
> of when each was introduced in conversation.

---

## Open items (explicitly not settled — do not treat as agreed)

- Roku's complete lack of any post-pairing identity re-derivation (see Problem #3) — no fix
  discussed; left open for now, not resolved by SG1–SG5.
- **Resolved, no longer open** — pre-existing paired Android TVs saved under the old
  `androidtv-<sha256>` scheme now auto-migrate to `androidtv-<mac>` via `AndroidTvLegacySha256IdMigrator`
  (T5.2), implemented as an explicitly *temporary* shim with a fixed removal date (~2026-11-10) — see
  T5.2's own entry and `references/tech-debt-list.md`. Was dropped once, then reopened; kept here in
  history only for anyone reading the git log, not as a current gap.
- A saved `androidtv-<mac>` device whose IP changes on the same scan neither `bt` nor a live cert
  connection works will not be reconciled that scan (T4.1, dropped) — accepted, decided with user:
  the only mechanism that could fire without a host anchor has real misfire risk (could merge two
  different physical TVs), and SG1's automatic retry means a later scan very likely recovers normally.
  Not a bug to fix later; logged here for the same reason as the item above.
- T5.1: whether the whole-DER-hash fallback (when subject-MAC parsing fails) is ever actually
  exercised in practice is unknown — logged in `references/tech-debt-list.md` to revisit once there's
  real-device coverage across more OEMs than the two confirmed subject-format examples.
- Exact numeric parameters used throughout this document (3 fast attempts, 5s cadence) were proposed
  during design discussion, not independently specified by the user as hard requirements — worth
  final confirmation if they prove wrong in practice. T1.2's own numbers (45s base, ×2, 5m cap) are
  now confirmed, not open.

---

## Done criteria (tentative)

- The remote/home page recovers from a transient port-level failure automatically, within one full
  cycle (fast phase + escalation + first wait), without requiring the user to reopen the app.
- The paired-list page's wifi icon reflects a freshly reconciled host within the same scan that
  found it, not requiring a second manual rescan.
- Both of the above work correctly today, against existing identity sources, independent of
  whether SG3/SG5 have landed yet.
- Any reachable Android TV — paired or not, `bt`-advertising or not — gets a `androidtv-<mac>`
  discovery-time id whenever a MAC is obtainable via either channel (mDNS `bt`, or a live cert read
  per SG5), without requiring prior pairing to have "recognized" it first.
- A previously-paired Android TV saved under `androidtv-<mac>` is reconciled correctly whenever a MAC
  is obtainable via *either* channel that scan. **Not covered, deliberately (SG4 dropped)**: a scan
  where the device's IP changed *and* neither `bt` nor a live cert connection worked that same scan —
  falls back to `androidtv-<ip>` unreconciled until a later scan recovers the MAC via SG1's automatic
  retry.
- A device still saved under the old `androidtv-<sha256>` scheme migrates to `androidtv-<mac>`
  automatically (T5.2) — temporarily, via `AndroidTvLegacySha256IdMigrator`, scheduled for removal
  ~2026-11-10 (see `references/tech-debt-list.md`); after removal, such a device again needs one
  manual re-pair, same as devices that migrate after that date.
- Devices with neither `bt` nor a connectable cert (Roku, manually-added, or an Android TV that's
  simply unreachable this scan) are unaffected — same behavior as today, no regression.
- `flutter analyze` clean; existing test suite green; new coverage added for SG5's certificate
  subject parsing, T5.2's migration filtering logic, and the retry state machine (T1.1).
