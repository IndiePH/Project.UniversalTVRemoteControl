# Goal: Stop reconnection loops from surviving backgrounding, and reflect retries in the connection-state label

**Branch:** `fix/reconnection-background-teardown` (current)
**Status:** Diagnosis complete (static code trace, not yet reproduced on hardware). Design went
through several revisions on 2026-09-11, each time after user pushback found a smaller or more
correct fix than the prior draft — see Design section, and especially the capability-interface
pattern's three-revision history. Final shape: delete both transport-level self-reconnect
schedulers, fix the retry controller's dead gap, lifecycle-gate `canAttemptNow`, and pause (not
disconnect) Hisense's poll timer while backgrounded. Not yet implemented — awaiting go-ahead.
**Related:** `references/device-identity-and-reconnection.md` (the automatic-reconnection-resilience work this bug was found in, commit `5c4994e`, PR #32), `references/tech-debt-list.md` (bare `catch (_)` pattern touched by this area)
**Retires when:** the fix ships and is confirmed to actually stop reconnect activity after backgrounding, on real hardware — at that point fold anything load-bearing into `references/device-identity-and-reconnection.md` and delete this file.

> ⚠️ **Not verified on hardware.** Everything below is a static trace through the code (file:line
> citations, confidence noted per claim) — I have not run the app and observed the described
> behavior directly. Per `bug-diagnosis` skill discipline this stands in for reproduction only
> because live reproduction wasn't available in this session; treat anything not marked
> "confirmed" as needing a runtime check before or during implementation.

---

## Problem statement

Two symptoms reported by the user, both regressions/gaps against commit `5c4994e` ("automatic
reconnection resilience and Android TV identity stability", PR #32):

1. Reconnection attempts appear to continue even after leaving the app to the Android home
   screen — the user's expectation, per the PR's own stated design (D-2 in the prior goal:
   "automatic reconnection is scoped to app-open only, no background service"), is that
   backgrounding stops it.
2. After the "Retrying in Xs" countdown reaches 0, the app does retry, but the connection-state
   label stays on "Connection error" instead of moving to "Connecting…".

**Symptom 2, clarified by the user (2026-09-11):** the expectation is that **the moment a retry
fires**, the label should reflect that. The user then asked the right follow-up question: is
there actually an assurance/confirmation that a retry is happening before the label changes, or
would flipping the label just be optimistic UI that might not match reality — and isn't
"waiting for confirmation that hadn't arrived" plausibly *why* it wasn't updating in the first
place? That pushback is correct and changed the diagnosis — see fact #8 (now confirmed, not just
likely) and the Design section below. The right fix is not "make the UI more willing to guess," it's
"make the real signal (the transport's own `connecting` emission) trustworthy and prompt enough to
just use directly" — a genuine root-cause fix rather than a cosmetic one.

## Verified facts

### Confirmed (direct source read)

1. `RemoteHomePage.didChangeAppLifecycleState` (`remote_home_page.dart:209-223`) on `paused`
   calls only `_retryController.stop()`. `ReconnectionRetryController.stop()`
   (`reconnection_retry_controller.dart:110-116`) cancels its own `Timer` and clears its own
   state — it has no reach into the transport layer.
2. `AndroidTvTcpTransportClient._onRemoteSocketDone` (`android_tv_tcp_transport_client.dart:697-715`)
   runs its own independent reconnect: on any socket close, if `_remoteActive` still contains the
   device, it waits 3s and calls `_connectRemote()` again — unconditionally, regardless of app
   lifecycle or which page is showing. `_remoteActive` is only cleared by `clearPairing()`
   (`android_tv_tcp_transport_client.dart:274-282`, the unpair flow) — never by backgrounding or
   navigating away.
3. `HisenseMqttTransportClient` runs a `_connectivityPollTimers` periodic timer per device
   (`hisense_mqtt_transport_client.dart:63,323-329`), started on connect. Each tick
   (`_pollConnectivity`, `:331-357`) both detects state (this poll is Hisense's *only* mechanism
   for noticing a drop — MQTT's own state alone isn't trusted) **and**, on the same tick, calls
   `_maybeReconnect` (`:364-378`) if disconnected. Only cancelled in `clearPairing()` (`:382`) —
   same lifecycle gap as Android TV.
4. **New, confirmed via `git log --diff-filter=A`:** Android TV's self-scheduled reconnect
   (`_onRemoteSocketDone`) was introduced in PR #9 (`b21d7f8`, 2026-05-11) — **over four months
   before** `ReconnectionRetryController` was added in PR #32 (`5c4994e`, 2026-09-10).
   `references/device-identity-and-reconnection.md` (PR #32's own design doc, consolidated) never
   mentions `_onRemoteSocketDone` or any transport-level reconnect at all. PR #32 added a
   page-level retry authority without accounting for — or removing — the transport-level one that
   already existed. The app has had **two independent, uncoordinated reconnect mechanisms**
   since PR #32 shipped, not one.
5. `ReconnectionRetryController._beginFastPhase()` (`reconnection_retry_controller.dart:139-145`)
   — used both by `start()` and when a wait-phase countdown reaches 0
   (`_beginWaitPhase`'s timer callback, `:218-229`) — starts a `Timer.periodic` with no immediate
   first tick, unlike `retryNow()` (`:121-131`), which fires `_attemptFastConnect()` immediately
   before starting its own timer. ~5s dead gap right when a wait countdown hits 0 or `start()` is
   first called.
6. The connection-state label ("Connection error" / "Connecting…" / etc.) is
   `connectionStatePresentation` (`connection_state_presentation.dart:9-38`), driven purely by
   `_connectionState`, itself set only from `widget.connectionStateService.watch(device)`
   (`remote_home_page.dart:356-374`) — a direct relay of whatever `ConnectionState` the active
   transport emits. Independent of `ReconnectionRetryController.stateNotifier` (drives only the
   separate "Retrying in Xs" row).
7. Every transport client does emit `ConnectionState.connecting` at the start of a connect
   attempt (confirmed across Android TV, Hisense, LG, Samsung, TCL/Roku, Sony) — the label
   mechanism itself is correctly wired, when there's a single trustworthy caller driving it.
8. **Elevated from "likely" to confirmed-mechanism** (exact runtime interleaving still
   unconfirmed without a live trace, but the mechanism causing it is now directly evidenced by
   fact #4): `_connectRemote()` (`android_tv_tcp_transport_client.dart:519-579`) guards against
   concurrent attempts — `if (_remoteConnecting.contains(deviceId)) return;` (`:521`) — silently,
   with **no state emission on the early return**. With two independent callers
   (`_onRemoteSocketDone`'s own 3s-later reconnect, and the page's `ReconnectionRetryController`)
   both able to call `connect()` for the same disconnected device, whichever one loses the race
   hits this guard and produces *no visible effect at all* — not a wrong label, literally nothing.
   That's a fully plausible, mechanism-confirmed explanation for "it retries but the label doesn't
   move": the page's retry can genuinely be the one that gets silently dropped.
9. **Confirmed by re-reading the code (2026-09-11, found while reasoning about battery impact) —
   a real gap in the fix as scoped through fact #8: `_retryController.stop()` on `paused` only
   stops the controller *once, at that moment*.** It does not prevent it from being restarted.
   `_subscribeConnectionState`'s listener (`remote_home_page.dart:356-374`) stays subscribed the
   whole time the widget is alive and unconditionally calls `_retryController.start(device)` on
   *any* later `disconnected`/`error` emission — regardless of app lifecycle. `canAttemptNow`
   (`remote_home_page.dart:157`) only checks `mounted && ModalRoute.of(context)?.isCurrent` —
   route-stack state, not OS lifecycle. `RemoteHomePage` stays "current" internally even while the
   whole app is backgrounded (nothing popped it), so this check does not gate on backgrounding at
   all. Net effect: deleting the transport-level scheduler (items 1-2 below) closes the *original*
   dual-authority race, but if the socket drops *again* later while still paused — which the
   keepalive-timeout mechanism (fact from the PR #9 changelog: TV closes after ~16s of unanswered
   pings, and backgrounding is what typically causes missed pings) makes likely, repeatedly, for as
   long as backgrounding continues — the page's own controller springs back to life and fires a
   connect attempt anyway. Each such attempt is a full TCP+TLS handshake; repeating every ~16-30s
   indefinitely while backgrounded is a real, non-trivial battery/radio cost, not just a UI issue.

## Design

### Revised understanding: the real root cause is the *second* reconnect authority, not the UI wiring

The first draft of this doc proposed adding an `ExplicitDisconnectCapable` capability so the page
could tell the transport to stop on background, plus an optimistic UI override that flips the
label to "Connecting…" as soon as the retry controller *decides* to retry, before confirming
anything actually happened. The user correctly pushed back on the optimistic half: flipping the
label without confirmation just relocates the lie, and doesn't explain why the real signal
(fact #7's `connecting` emission) wasn't already showing up. Fact #4 answers that: it wasn't a
missing signal, it was a **second, pre-existing, uncoordinated reconnect scheduler** competing
with the one just added in PR #32 and frequently winning the race silently (fact #8).

Once there is only **one** authority initiating reconnects, fact #7 already holds — the label
doesn't need a special case, because the real `connecting` emission arrives, and arrives from an
attempt the page itself knows it triggered. This is a smaller, more surgical fix than the first
draft, and it directly satisfies the user's "only change the text once we get a promise it's
trying" bar — the promise is the transport's own state emission, made trustworthy by removing the
second scheduler that was stepping on it.

### Chosen approach: delete the transport-level self-reconnect; `ReconnectionRetryController` becomes the sole retry authority

1. **Android TV** (`android_tv_tcp_transport_client.dart`): in `_onRemoteSocketDone` (`:697-715`),
   keep `_cleanupRemote(deviceId)` and `_emitState(deviceId, ConnectionState.disconnected)`
   (`:699-700`) — the page still needs to hear about the drop — but delete the self-scheduled
   reconnect below it (`:702-714`: the `_remoteActive` guard, `Future.delayed(3s)`, and the
   `_connectRemote` retry-and-catch). `_remoteActive` becomes fully unused once this is gone
   (only ever read at `:704`, written at `:277`/`:569`/`:712`) — remove the set and its 4 sites
   entirely rather than leaving dead state behind.
2. **Hisense** (`hisense_mqtt_transport_client.dart`): in `_pollConnectivity` (`:331-357`), keep
   both `_emitConnectionState(...)` calls (state detection is this poll's real job) but delete
   the two `await _maybeReconnect(deviceId);` calls (`:337`, `:355`). `_maybeReconnect` (`:364-378`)
   and `_reconnectInFlight` (`:67`) become fully unused (no other callers) — remove them.
3. Fix `_beginFastPhase()` to fire an attempt immediately (mirror `retryNow()`'s pattern:
   call `_attemptFastConnect()` once before starting the periodic timer) — closes the ~5s dead
   gap from fact #5, so the now-single, now-trustworthy retry attempt (and its `connecting`
   label) shows up as promptly as possible.
4. No change needed to the status-label wiring itself (`connectionStatePresentation`,
   `RemoteHomePage._subscribeConnectionState`) — it was already correct; it just never got a
   trustworthy, prompt signal to relay.
5. **Revised (fact #9): `stop()` alone is not sufficient — `canAttemptNow` needs an app-lifecycle
   check, not just a route check.** Extract the inline lambda into a named private getter on
   `_RemoteHomePageState` (per `clean-code-solid`: the three-condition inline boolean at the
   constructor call site mixes abstraction levels and should be a named predicate, one name per
   intention, matching the existing `canAttemptNow` vocabulary):
   ```dart
   bool get _canAttemptNow =>
       mounted &&
       WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
       ModalRoute.of(context)?.isCurrent == true;
   ```
   passed as `canAttemptNow: () => _canAttemptNow`. This closes fact #9's gap: even if `start()`
   gets called again while paused, every fast-phase tick is a no-op skip (not counted) until the
   app actually resumes — no connect attempt fires while backgrounded, however many times the
   controller gets restarted in the meantime.
6. **Proposed, then dropped again, per user 2026-09-11 — scenario analysis favors leaving the
   connection alone.** Item 5's predecessor draft proposed proactively closing an already-healthy
   connection the instant the app backgrounds ("stop" should mean stop everything). Comparing the
   two actual cases changed the conclusion:
   - **Brief backgrounding** (accidental home-press, a few seconds' app-switch): forcing an
     explicit disconnect on *every* pause means a full TCP+TLS handshake and a visible
     "Connecting…" flash on *every* such event, however short — worse than today. Leaving the
     connection alone means the (very likely common) case where the user returns before the TV's
     own ~16s keepalive-timeout fires costs *nothing* — no interruption at all.
   - **Long backgrounding**: an explicit disconnect saves only the idle tail-end before the TV's
     own timeout would have closed it anyway — an idle open socket doing nothing costs little; the
     real cost was always the handshake, not idle time.
   Net: proactive disconnect trades a real, guaranteed cost on the common case for a marginal
   saving on the uncommon one. **Dropped.** The device's own protocol-level timeout (confirmed
   TV-side, not app-controlled — PR #9's changelog) is left to run its course; item 5 alone (don't
   *reconnect* while backgrounded) is the correct and sufficient intervention on our side.
7. **New, per user 2026-09-11 — Hisense's poll timer should pause while backgrounded, resume on
   foreground.** Unlike Android TV (no polling mechanism of its own — see fact #9's discussion,
   nothing to pause), `HisenseMqttTransportClient._connectivityPollTimers` is a real, active
   `Timer.periodic(8s)` that keeps running and probing regardless of app lifecycle, independent of
   whether it tries to reconnect (already removed per item 2). Per the same "leave the connection
   itself alone" principle as item 6 — this pauses *our own polling*, not the underlying MQTT
   connection, which is still left to time out naturally on its own schedule. **Confirmed
   approach:** pause immediately on `paused` (mirrors item 5's mechanism exactly — same moment
   `_retryController.stop()` fires), resume and do one fresh check on `resumed`. Needs a small
   capability interface (`HisenseMqttTransportClient` is the only implementer — Android TV has
   nothing to pause), following the same `TransportLogReaderProvider`-precedent shape used
   elsewhere in this codebase: two new methods on `RemoteCommandService` (`pauseMonitoring`/
   `resumeMonitoring`, separate named methods rather than one boolean-flag method — per
   `clean-code-solid`'s guidance against flag arguments that change behavior), implemented by all
   3 `RemoteCommandService` implementers, delegating to a capability check (`is
   BackgroundPollAware`) in `BrandRoutedRemoteCommandService` so brands with nothing to pause are
   untouched. Called from `didChangeAppLifecycleState` — `pauseMonitoring` alongside
   `_retryController.stop()` on `paused`, `resumeMonitoring` alongside the existing
   `_retryController.start()` path on `resumed`.

8. **New, per user 2026-09-11 — confirmed by re-reading the code, not assumed:** the "don't
   monitor a device that isn't the actively selected remote" principle the user proposed is
   already true for how connections get *established* — `connect()` (and, for Hisense,
   `_startConnectivityPolling`) is only ever called by `RemoteHomePage`/`ReconnectionRetryController`
   for whichever device is `_activeDevice` (confirmed via the same grep as fact #4's investigation:
   no other call site exists anywhere in the app). The paired-device list's "green wifi" indicator
   (`_PairedTvConnectionIndicator`, `pairing_page_sections.dart:266-309`) already uses a separate,
   genuinely lightweight one-shot `probe()` (`hisense_mqtt_transport_client.dart:277-286`: raw
   `Socket.connect()` + immediate `destroy()`, no session, no polling started) — confirmed via
   `HisenseAdapter.probeConnection` (`hisense_adapter.dart:48-51`), which calls `probe()`, not
   `connect()`/`_ensureConnected`. Triggered once on `PairingPage.initState` (`pairing_page.dart:
   118`) and again only on an explicit scan-button tap (`:624`) — no recurring timer anywhere.
   `FutureBuilder`'s pending state is a small spinner, resolved state a static icon
   (`pairing_page_sections.dart` build method) — the UI does not visually claim to be continuously
   live, and it isn't. **No change needed for the paired-list page.**
9. **New gap found while verifying fact #8, real and previously undiscussed:** switching the
   active device (device switcher) does **not** tear down the *previous* device's connection.
   `_subscribeConnectionState` (`remote_home_page.dart:341-383`) stops the retry controller and
   cancels the page's own stream subscription, but never signals the transport layer that the old
   device is no longer active. For Hisense specifically, its MQTT client and
   `_connectivityPollTimers` for the deselected device keep running indefinitely — the same class
   of problem as backgrounding, just a different trigger (device-switch instead of app-lifecycle),
   and not covered by anything designed so far.

### Design item 8: pause monitoring on device deactivation, not just app-background

Reuses the exact `pauseMonitoring` primitive from item 7 — no new interface, no new capability
(passes `design-pattern-selection`'s DA-5: added call site, zero added complexity). In
`RemoteHomePage._subscribeConnectionState`, before switching to a new device (or clearing to
`null`), call `commandService.pauseMonitoring(device: previousDevice)` for whatever was active
before — only when there *was* one and it differs from the new target (guards the initial-load
case where `_activeDevice` starts `null`). Switching *to* a device needs no matching
`resumeMonitoring()` call: `_ensureConnected`'s "already connected" branch already unconditionally
restarts polling on every `connect()`, which `_subscribeConnectionState` already calls
unconditionally today.

Edge cases checked (`correctness-validation`'s "validate all edge cases explicitly," not just the
happy path) before treating this as settled:
- **Rapid A→B→A switching**: pausing A's timer on switch-to-B, then switching back to A calls
  `connect(A)` again, which restarts A's polling cleanly (`_startConnectivityPolling` cancels any
  existing timer before reassigning, so it's idempotent even if called more than once).
- **Very first activation** (`_activeDevice` was `null`): guarded above — no spurious
  `pauseMonitoring(null)` call.
- **Unpairing the active device** (→ `_activeDevice = null`): should get the same
  `pauseMonitoring` call on whatever was active — shares a call site with the Open question 4 fix
  (clear `_activeDevice` on unpair), not a separate mechanism.

**Cross-reference, not a new item:** this is a second, independent instance of the exact layering
tension already logged in `tech-debt-list.md` (`ReconnectionRetryController`'s ownership sitting
in `RemoteHomePage` instead of the domain layer) — device-active-state tracking living in a page
widget is what creates both gaps. Noted there, not re-logged separately; fixed pragmatically
through the page for this goal, consistent with everything else in it.

Total estimated surface: still **9 files** — item 8 adds a call site inside files already being
touched (`remote_home_page.dart`, `hisense_mqtt_transport_client.dart` needs no *new* method,
`pauseMonitoring` already covers this), not new files. `android_tv_tcp_transport_client.dart`
(item 1), `hisense_mqtt_transport_client.dart` (items 2 + 7), `reconnection_retry_controller.dart`
(item 3), `remote_home_page.dart` (item 5's getter + item 7/8's lifecycle and device-switch calls +
the unpair fix), `remote_command_service.dart` + its 3 implementers (item 7's new methods), one new
small capability interface file (item 7) — still far short of the ~22-file naive approach from the
very first draft, and no full teardown/reconnect-on-every-blip cost anywhere in the design.

### Capability-interface pattern — proposed, superseded, revived, narrowed: final shape

Worth being precise about the path here, not just the ending (per `design-pattern-selection`'s
DT-1: document *why*, not just the current answer), since it changed three times in one session.
**Originally** proposed (`ExplicitDisconnectCapable`) to let the page tell a runaway
transport-level scheduler to stop (fact #2's Android TV loop) — **superseded** once fact #4 showed
deleting that scheduler entirely was simpler, nothing left to explicitly stop. **Revived** for
proactive full-connection teardown on backgrounding ("stop means stop everything") — **superseded
again** (item 6 above) once the brief-vs-long-backgrounding scenario comparison showed that trades
a real cost for a marginal one. **Final shape** (item 7): much narrower than either earlier
version — not "disconnect," just "pause our own background polling" — and scoped to Hisense only,
since Android TV never had a poll loop to pause in the first place. The general shape (small
optional capability interface, mirrors `TransportLogReaderProvider`, implemented only where a
brand actually needs it) survived all three revisions even though what it *does* changed each
time. **Not yet decided:** whether LG/Samsung's WebSocket connections have anything analogous
worth pausing — flagged as worth asking about, not assumed in or out of scope.

## Open questions

1. Was `_onRemoteSocketDone`'s self-reconnect (and Hisense's `_maybeReconnect`) *intentional*
   resilience for the case where the app is mid-use with the page's retry controller not
   involved yet (e.g. a transient drop during active remote use before any UI-visible
   "disconnected" state settles)? From reading `_subscribeConnectionState`
   (`remote_home_page.dart:341-383`), the page's own controller starts on the *first*
   `disconnected`/`error` emission it observes (`state.shouldAutoReconnect`), which
   `_onRemoteSocketDone`'s `_emitState(disconnected)` (kept in this design) still triggers
   immediately — so there should be no coverage gap from removing the self-reconnect. Worth a
   deliberate check during implementation, not just an assumption.
2. ~~Should the app still proactively close idle live sockets/MQTT connections when
   backgrounded?~~ — **resolved 2026-09-11, final answer: no.** Went through two rounds: first
   deferred as a "future enhancement," then briefly pulled into scope after the battery-cost
   discussion, then dropped for good once the brief-vs-long-backgrounding scenario comparison
   showed it trades a real, guaranteed cost (forced reconnect+flicker on every brief accidental
   background) for a marginal one (saving an idle socket's last ~16s). See Design item 6. What
   *is* in scope instead: Hisense's poll timer pausing while backgrounded (item 7) — pausing our
   own monitoring, not touching the underlying connection. Remaining open sub-question: whether
   LG/Samsung's WebSocket connections have anything analogous to item 7 worth pausing — not
   decided.
3. Bare `catch (_)` in `_connectRemote`'s original retry path is being deleted along with the
   retry itself, not modified — no new tech-debt entry needed there. Confirm no other bare-catch
   cleanup is implied by this change during implementation.
4. **In scope, per user 2026-09-11 — pre-existing race, independent of the rest of this goal,
   not introduced by it:** `clearPairing()`'s `_emitState(disconnected)` (any brand, not just
   Android TV) reaches `RemoteHomePage._subscribeConnectionState`'s listener exactly like any
   other disconnect, which calls `_retryController.start(device)` — regardless of *why* the
   device disconnected. If the unpaired device is `_activeDevice` and `RemoteHomePage` is still
   mounted underneath the Pairing page when this happens, the retry controller starts (gated
   inert by `canAttemptNow()` while the Pairing page is on top). Today this is very likely
   benign in practice: `_openPairing()`'s own continuation (`_activeDevice = null` or
   `_activateDevice(newDevice)`, both go through `_subscribeConnectionState`, which calls
   `_retryController.stop()` first) runs essentially immediately on returning from the Pairing
   page, well ahead of the retry controller's own ~5s-spaced next check — but this is a timing
   race, not a structural guarantee, and hasn't been verified live. **Fix, per user direction:**
   in `RemoteHomePage`, when an unpair completes for a device matching `_activeDevice?.id`,
   explicitly clear `_activeDevice`/stop the retry controller synchronously at that point,
   rather than relying on `_openPairing()`'s incidental cleanup timing to win the race. Needs
   its own call site — `unpairDevice` today is only invoked from `PairingPage`
   (`pairing_page.dart:471,510`), which has no direct reference back into `RemoteHomePage`'s
   state; likely needs a callback/result threaded back through `RemoteHomeActions.openPairing`
   (already returns a value `_openPairing` reads) or an explicit check against the returned
   device list. Exact wiring to be determined during implementation. **Resolved, see
   Implementation notes item 4.**

## Implementation notes (found during implementation, not anticipated in design)

Two things surfaced only once code was actually written and the *full* test suite run against
it — not just the narrow unit-test file for whatever was just changed. Recorded per `bug-diagnosis`'s
GM-4 (document findings with evidence) rather than silently folded into the diff.

1. **DRY violation, found applying `clean-code-solid` to the item-3 diff itself:**
   `ReconnectionRetryController._beginFastPhase()` and `retryNow()` became identical in their last
   four lines once the dead-gap fix landed (they weren't duplicates before — `_beginFastPhase`
   didn't fire immediately). Collapsed: `retryNow()` now does its own guard/cancel/growth-reset,
   then delegates to `_beginFastPhase()` instead of repeating its body.
2. **Real regression, found while verifying item 5 (the lifecycle-gated `_canAttemptNow`
   getter) against the full `widget_test.dart` suite, not just the isolated controller unit
   tests:** `_subscribeConnectionState`'s unconditional `unawaited(widget.commandService.connect
   (device: device))` at the end became a genuine duplicate dial once item 3's dead-gap fix
   shipped. `MultiplexedTvConnectionStateService.watch()` always replays a value synchronously on
   `.listen()` (defaulting to `disconnected` for a device with no cached state this session), so
   for any freshly-subscribed device the listener's `disconnected`/`error` branch now *also* fires
   an immediate connect via `_retryController.start()` — racing the pre-existing explicit call.
   Likely harmless in practice (every brand has some concurrent-connect guard that would absorb
   the second dial), but a genuine, avoidable duplicate, not something to paper over by bumping
   affected tests' expected counts from 1 to 2. **Fixed:** removed the explicit call entirely —
   verified against all 7 call sites of `_subscribeConnectionState`; the 3 that pass `null` never
   reach it, and the remaining ones (cold start, device switch, the rare `didUpdateWidget`
   command-service-swap path) are all correctly handled by the replayed state triggering the
   retry controller instead. This also makes the very first connect attempt respect
   `canAttemptNow`'s gate like every other retry-controller-driven connect already does, instead
   of being an ungated special case — a consistency improvement, not a new risk, given the whole
   point of this goal is one authority for "should we dial right now." All 3 previously-failing
   `widget_test.dart` tests pass again; full file (32 tests, 1 pre-existing skip) green.

Both were caught specifically because the *broader*, cross-file test suite was run after each
change, not just the narrowly-scoped unit test file for whatever was being touched at the time —
worth keeping as the standard going forward for the remaining tasks (5, 6, 9), not a one-off.

3. **Design items 7/8 implemented as specified, with one mechanical consequence not spelled out
   in the design:** added `BackgroundPollAware` (`application/background_poll_aware.dart`,
   `pauseMonitoring`/`resumeMonitoring`, mirrors `TransportLogProvider`'s shape exactly) and the
   same two methods on `RemoteCommandService` itself, implemented by all 3 real implementers
   (`BrandRoutedRemoteCommandService` delegates via `is BackgroundPollAware` capability check —
   `HisenseAdapter` is the only implementer; `InMemoryRemoteCommandService` and
   `DiagnosticsRecordingRemoteCommandService` no-op/delegate respectively). `HisenseAdapter`
   delegates to new `HisenseTransportClient.pauseMonitoring`/`resumeMonitoring` methods
   (`deviceId`-keyed, added to the abstract transport interface itself since
   `FakeHisenseTransportClient` also `implements` it — Dart's `implements` erases default method
   bodies even on an abstract class, confirmed by testing it directly, so every implementer of
   `HisenseTransportClient` needed an explicit override regardless of whether the interface method
   had a body). `HisenseMqttTransportClient`'s real implementation just cancels/restarts
   `_connectivityPollTimers[deviceId]` (`pauseMonitoring`) and restarts-plus-one-fresh-check
   (`resumeMonitoring`) — the underlying MQTT client itself is never touched by either call, per
   the design. Confirmed via the same `implements`-erasure fact: every `RemoteCommandService`
   implementer — including 7 test fakes across 6 test files — needed a trivial override too; these
   got plain no-ops (or `throw UnimplementedError()` where the existing fake already used that
   convention for unused members, e.g. `reconnection_retry_controller_test.dart`'s
   `_RecordingCommandService`) rather than real assertions, since meaningfully testing
   pause/resume behavior is Task 6's job, not this one's.

   `RemoteHomePage` wiring: `didChangeAppLifecycleState` calls `pauseMonitoring` alongside
   `_retryController.stop()` on `paused`, and `resumeMonitoring` on `resumed` — gated only on
   `_activeDevice != null`, deliberately *not* on `_connectionState.shouldAutoReconnect` like the
   adjacent `_retryController.start()` call is, since the poll's job is to (re)detect the real
   connection state after a background spell, not to only run when reconnection policy already
   expects a problem. `_subscribeConnectionState` gained an optional `previousDevice` parameter
   (pauses it when non-null and different from the new device) — added because by the time any
   existing call site invoked `_subscribeConnectionState`, `_activeDevice` had already been
   reassigned to the *new* device by that call site's own `setState`, so the method could not
   simply read `_activeDevice` itself to recover "what was active a moment ago"; each of the 3
   call sites that can genuinely change the active device (`_activateDevice`,
   `_refreshSavedDevicesForFreeTier`'s clear-to-null branch, `_openPairing`'s clear-to-null branch)
   now captures `_activeDevice` into a local *before* its own `setState` overwrites it, and passes
   that through. `_loadInitialDevice` (cold start) and `didUpdateWidget` (command-service swap, same
   device) both correctly pass no `previousDevice` — the former because `_activeDevice` is
   genuinely null pre-activation, the latter because the device isn't changing at all.

   Verified: `flutter analyze` clean; full `flutter test` run (784 tests) green, including
   `hisense_test_lane_test.dart` and every widget/controller/adapter test touched by the interface
   change.

4. **Open question 4 resolved: `PairingPage` gained an optional `onDeviceUnpaired(String
   deviceId)` callback**, invoked from both of its existing unpair call sites
   (`_confirmRemoveSavedDevice`, `_offerLegacyCleanup`) the moment a device is actually removed —
   while the Pairing page is still open, not gated on ever popping back. `PairingPage` itself
   stays brand-/caller-agnostic: it reports "this id was just unpaired" unconditionally and lets
   the caller decide whether it matters, mirroring how `_handleDeviceUpdatedByReconciliation`
   already treats a device-id match as the caller's call, not the reporter's.
   `RemoteHomeActions.openPairing` gained a matching optional parameter threaded straight through
   to the `PairingPage` it constructs. `RemoteHomePage._openPairing()` passes
   `_handleActiveDeviceUnpaired`, which no-ops unless the reported id matches `_activeDevice?.id`,
   then delegates to a new `_clearActiveDevice()` helper.

   `_clearActiveDevice()` is an extraction, not new behavior: the two existing "no active device"
   branches (`_refreshSavedDevicesForFreeTier`'s and `_openPairing`'s own null-device branch) were
   byte-for-byte identical blocks (setState clearing `_activeDevice`/status/layout-edit-mode, then
   `_subscribeRemoteTextReady(null)` + `_subscribeConnectionState(null, previousDevice:
   previousDevice)` + `_resetLayoutToDefaults()`) — adding a third near-identical call site made
   the duplication worth collapsing (`clean-code-solid`). Because `_subscribeConnectionState`
   already handles a non-null `previousDevice` by pausing its background monitoring and stopping
   the retry controller (Design item 7/8's own machinery), this one helper call gives the new
   unpair path the exact same synchronous stop+pause guarantee item 8 asked for ("shares a call
   site with the Open question 4 fix") with no separate mechanism needed. Added a `mounted` guard
   inside `_clearActiveDevice()` itself (harmless no-op for the two pre-existing call sites, which
   were always already-mounted-checked; load-bearing for the new callback path, which can fire
   from a different widget's async callback after `RemoteHomePage` could in principle have been
   disposed).

   Verified: `flutter analyze` clean; full `flutter test` run (784 tests, 1 pre-existing skip)
   green, including the pre-existing `widget_test.dart` test `'clears active device when current
   paired TV is removed'`, which still passes even though it only asserts *after* popping back —
   confirming the new synchronous path and the old pop-triggered path converge on the same end
   state rather than one masking a bug in the other.

## Test plan (per `test-creation-strategy`/`regression-prevention`)

- `AndroidTvTcpTransportClient` unit test: after `onDone` fires on the remote socket, no second
  `_connectRemote()` call happens on its own (no 3s-later reconnect) — the direct regression test
  for symptom 1 on this brand. A `disconnected` state is still emitted immediately.
- `HisenseMqttTransportClient` unit test: after a poll tick detects a drop, `_emitConnectionState`
  fires but no further connect attempt is self-initiated.
- `ReconnectionRetryController` unit test: `_beginFastPhase` fires a connect attempt immediately
  on `start()` and when a wait countdown reaches 0, not after the first 5s tick. **Not just new
  coverage — existing tests assert the current dead-gap as correct and must be rewritten, not left
  broken:** `reconnection_retry_controller_test.dart:40` (`'fast phase does not fire an immediate
  connect on start'` — name and assertion both need to flip), `:56-88` (expects
  `connectCallCount == 1` only after the first 5s elapse, not at t=0), `:117`'s comment on the
  wait-loop-back test ("no immediate fire, one connect per subsequent 5s tick").
- Integration-shaped test (fake transport + real `ReconnectionRetryController` +
  `RemoteHomePage` or an equivalent harness): simulate a drop, assert exactly one connect
  authority reacts, and that the connection-state label transitions to "Connecting…" promptly
  and without a silently-dropped attempt — the direct regression test for symptom 2 and the
  user's "only after confirmation" requirement.
- `RemoteHomePage` lifecycle test: `didChangeAppLifecycleState(paused)` → `_retryController.stop()`
  is called and, with the transport-level fix in place, no further connect attempts occur while
  paused (simulated via a fake transport, since the real regression is cross-layer).
- `RemoteHomePage` unpair test (Open question 4): unpairing the currently-active device from the
  Pairing page clears `_activeDevice`/stops the retry controller synchronously — assert no
  `connect()` call is ever made against the unpaired device, removing the timing race entirely
  rather than relying on it resolving favorably.
- `RemoteHomePage` lifecycle-gate test (fact #9 / Design item 5): with the app paused
  (`WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed`), a `disconnected`
  emission arriving after `_retryController.stop()` was already called must not result in any
  `connect()` call — even though `start()` gets invoked again by `_subscribeConnectionState`'s
  listener, `_canAttemptNow` must gate every subsequent attempt until resume.
- `RemoteHomePage` background-monitoring test (Design item 7): `didChangeAppLifecycleState(paused)`
  calls `commandService.pauseMonitoring(device: _activeDevice!)` alongside
  `_retryController.stop()`; `didChangeAppLifecycleState(resumed)` calls `resumeMonitoring(...)`
  alongside the existing `_retryController.start()` path.
- `HisenseMqttTransportClient` `pauseMonitoring`/`resumeMonitoring` unit tests:
  `pauseMonitoring` cancels `_connectivityPollTimers[deviceId]` with no further poll ticks;
  `resumeMonitoring` restarts it and triggers one immediate fresh check. The underlying MQTT
  client itself is never explicitly disconnected by either call — only the poll loop is affected.
- `BrandRoutedRemoteCommandService` capability-check test: `pauseMonitoring`/`resumeMonitoring`
  delegate only when the resolved adapter `is BackgroundPollAware` (Hisense) — no-op for a brand
  with nothing to pause (e.g. LG), confirming no unintended behavior change for other brands.
- `RemoteHomePage` device-switch test (Design item 8/fact #9): activating device B while device A
  is active calls `pauseMonitoring(deviceA)` before subscribing to B; the very first activation
  (from `null`) does not call `pauseMonitoring` at all; switching A→B→A restarts A's polling
  cleanly via the normal `connect()` path, no leaked or duplicate timer.
