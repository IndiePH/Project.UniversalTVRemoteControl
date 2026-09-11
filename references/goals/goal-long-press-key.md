# Goal: Long-Press / Hold Key Support

**Branch:** `feature/long-press-key`
**Status:** Implemented and shipped (2026-09-11). Sub-goals A (research), B (design), and C
(implementation) are all done. Scope: **officially-supported-only — Android TV family
(`AndroidTvAdapter`, `TclGoogleTvAdapter`, `SonyAdapter`), Samsung (`SamsungAdapter`), Roku
(`TclRokuAdapter`)**. LG, Sony BRAVIA, Hisense VIDAA, TCL legacy WiFi are out of scope, not
deferred. `flutter analyze` and the full `flutter test` suite (804 tests) are clean. Not yet
validated against real hardware — see "Open items" below.
**Related:** `references/guide-tv-remote-protocols.md` (Android TV Remote Protocol v2 section already
documents the `RemoteDirection` enum this goal depends on), `references/guide-remote-command-dispatch.md`
(the `CommandPayload`/`CommandKeyMap` one-shot dispatch contract this goal needs to extend)
**Retires when:** the feature ships and is validated on real hardware for at least the brands with a
confirmed native hold primitive — at that point load-bearing protocol facts here should migrate into
`guide-tv-remote-protocols.md` per this project's established pattern (see `goal-sony-adapter.md`'s own
retirement clause) and this file should be deleted.

> ⚠️ **This document has not been verified or approved by the user beyond the initial request.**
> Section "Verified facts — codebase" is high confidence (direct source reads, file:line cited).
> Section "Verified facts — external protocols" started this session from general knowledge/prior
> research context, not fresh citations — being actively re-verified by parallel research agents
> (see "Research dispatch" below). Treat anything not carrying a source link as unconfirmed until an
> agent's findings are folded in.

---

## Problem statement

Real TV remotes overload several buttons with a long-press behavior distinct from a normal tap —
holding OK opens a context menu, holding Home opens the recents/app-switcher, holding Left/Right
scrubs continuously through video playback instead of a single skip. This app has none of that today,
on any brand: every button is a single atomic tap, both in the UI and in the wire protocol dispatch.

The goal is to determine, brand by brand, which of this app's adapters could actually support a real
hold gesture (protocol has a native press/release or start/end primitive) versus which would need a
client-side emulation (repeated fast taps while the button is held), and produce a scoped, sequenced
implementation plan.

---

## Verified facts — codebase (direct source reads, high confidence)

1. **UI layer has no press/release distinction anywhere.** `RemoteButton` (`remote_button.dart`)
   takes a single `VoidCallback onPressed`. `RemotePressFeedback` (`remote_press_feedback.dart:40-47`)
   fires that callback once, on `onTapDown` — there is no `onTapUp`/hold timer/repeat logic in this
   widget or anywhere else in `lib/remote_control/presentation/`. `RemoteDpad` and
   `RemoteCircularDpad` (`remote_dpad.dart`, `remote_circular_dpad.dart`) both wrap buttons in exactly
   this same single-fire pattern — confirmed for D-pad Up/Down/Left/Right/OK specifically, the buttons
   most relevant to this feature.
2. **Dispatch layer is one-shot, with no press-state concept.** Every adapter's `sendCommand`
   resolves a `RemoteCommand` to exactly one `CommandPayload` via `CommandKeyMap.payloadFor` and sends
   it once (`guide-remote-command-dispatch.md`'s documented `sendCommand` shape). No brand's
   `sendCommand` signature, and no `CommandPayload` subclass, carries a direction/press-state
   parameter today.
3. **Android TV Remote Protocol v2 already has a native long-press primitive, unused.**
   `android_tv_remote_messages.dart` defines `RemoteDirection { UNKNOWN_DIRECTION, START_LONG,
   END_LONG, SHORT }` (mirrors `guide-tv-remote-protocols.md`'s documented protobuf enum). But
   `android_tv_tcp_transport_client.dart:166` (`sendKey`) hardcodes `direction: RemoteDirection.short`
   for every send — the capability exists in this app's own protobuf classes and is simply never
   invoked with anything but `.short`. This is the adapter behind `AndroidTvAdapter`,
   `TclGoogleTvAdapter`, and `SonyAdapter` (Sony's Google TV line) — all three would get this for free
   from one transport-client change.
4. **Samsung's `sendKey` hardcodes a single `Cmd` value.** `samsung_websocket_transport_client.dart:266-274`
   sends `{'Cmd': 'Click', 'DataOfCmd': keyCode, 'Option': 'false', 'TypeOfRemote': 'SendRemoteKey'}`
   via `ms.remote.control` — `'Click'` is the only `Cmd` value ever sent in this codebase today.
5. **Roku's transport only ever calls `/keypress/`.** `roku_http_transport_client.dart:44-48`
   (`sendKey`) posts to `/keypress/$keyCode` exclusively.
6. **LG's `sendKey` is a single stateless SSAP call.** `lg_websocket_transport_client.dart:199-200`
   — `_sendSsap(deviceId:, uri: keyCode, payload: const {})`, one request, no press/release pairing
   visible anywhere in this app's LG transport surface (including `sendPointerCommand`,
   `lg_websocket_transport_client.dart:202-206`).
7. **Sony BRAVIA IRCC-IP has no press/release verbs in the catalog this repo already researched.**
   `guide-tv-remote-protocols.md`'s "Command catalog" section (written during the Sony Bravia
   research spike, see `goal-sony-adapter.md`) describes IRCC codes as base64 command emulation with
   no documented press/hold distinction anywhere in that section.
8. **Hisense VIDAA's `sendKey` publishes one MQTT string per press.**
   `hisense_mqtt_transport_client.dart:147-162` — `_publishString(client, _sendKeyTopic(), keyName)`,
   no press/release pairing. `hisense_validation_matrix.md` (this repo's own on-device test runbook)
   does not mention hold/long-press anywhere.
9. **TCL legacy WiFi opens a new TCP socket per key event.** `tcl_legacy_tcp_transport_client.dart:52-67`
   (`sendFrame`) does `Socket.connect` → write → `close()` for every single frame — structurally the
   worst fit in this codebase for a repeat-based hold emulation, since every repeated tap during a
   hold would pay a fresh TCP handshake.
10. **No new `RemoteCommand` enum values are needed for Android TV's case.** `home`, `menu`, `dpadOk`,
    `dpadLeft`, `dpadRight` already exist in `remote_command.dart`. A real Android TV long-press is the
    *same* keycode sent with a different `RemoteDirection` — the OS itself decides what UI that
    produces (recents on held Home, context menu on held OK). No protocol-level "long-press home"
    command is a separate thing to add.

## Verified facts — external protocols (unverified this pass — see Research dispatch)

These carry forward from a prior research pass in this conversation, not fresh citations. Listed here
so the research agents below have a concrete claim to confirm, correct, or refute — **do not treat any
line in this section as settled** until it has a source link attached.

11. ~~Samsung's `ms.remote.control` `Cmd` field is commonly documented across community
    reverse-engineering (samsungctl, various Home Assistant discussions) as accepting `'Click'`,
    `'Press'`, and `'Release'` — implying real down/up semantics distinct from Click.~~ —
    **CONFIRMED, see "Verified facts — Samsung (confirmed)" below.**
12. ~~Roku's public External Control Protocol (ECP) is commonly cited as having `/keypress/$key`,
    `/keydown/$key`, and `/keyup/$key` as three distinct endpoints. Not yet confirmed against Roku's
    own developer docs in this pass.~~ — **CONFIRMED, see "Verified facts — Roku (confirmed)" below.**
13. ~~LG webOS's pointer-socket/SSAP surface is believed to have no distinguishable "hold" wire
    message — physical Magic Remote long-press behavior is assumed to be handled by the remote's own
    firmware generating repeated events, not by a protocol verb the client could send instead.~~ —
    **CONFIRMED, see "Verified facts — LG webOS (confirmed)" below.**
14. ~~Sony BRAVIA IRCC-IP and Hisense VIDAA are assumed to have no hold primitive at all, based on the
    absence of one in the catalogs already surveyed.~~ — **CONFIRMED, see "Verified facts — Sony
    Bravia / Hisense (confirmed)" below.**
15. ~~Whether Android TV's `START_LONG` requires the client to keep sending something for the
    duration of the hold, or whether the OS auto-repeats internally once `START_LONG` is received, is
    unknown.~~ — **CONFIRMED, see "Verified facts — Android TV (confirmed)" below.**

## Verified facts — Android TV (confirmed, Research agent 1, 2026-09-11)

30. **High confidence, direct source read.** `tronikos/androidtvremote2`'s `send_key_command()`
    sends exactly one `RemoteKeyInject` message with no internal timing/repeat logic — the proto
    itself (`remotemessage.proto`) is silent on timing; behavior is entirely caller convention. Home
    Assistant's `androidtv_remote` integration (built on this library) implements hold as a **true
    two-message pair with nothing sent in between**: `send_key_command(key, "START_LONG")` →
    `asyncio.sleep(hold_secs)` → `send_key_command(key, "END_LONG")`. HA's own docs confirm this
    explicitly: "the integration will press the key, wait the given duration, and then release it."
    **This is the exact same shape as Roku's `keydown`-sleep-`keyup` pattern (fact #17) and Samsung's
    `press`-sleep-`release` pattern (fact #22)** — three independently-researched brands converging
    on the identical "single down message, wall-clock wait, single up message" design. Strong signal
    this is the correct general shape for this app's own hold-tracking state, not brand-specific.
31. **Medium confidence (reasonable inference, not directly sourced).** The receiving Android TV
    Remote Service almost certainly injects a standard Android `ACTION_DOWN` on `START_LONG` and
    `ACTION_UP` on `END_LONG`, letting the OS's own input framework (same as a physical remote)
    determine long-press/repeat UI behavior from elapsed time between the two — consistent with fact
    #30's evidence but not confirmed via packet capture of Google's own official app.
32. **Medium-high confidence, official + community sources.** Real-world long-press UX confirmed:
    D-pad Left/Right → continuous scrub during playback is **officially documented** by Android
    Developers (`developer.android.com/training/tv/playback/controls`: single press = jump ±N
    seconds, press-and-hold = continuous scrubbing). Home → recents/app-switcher confirmed via
    Android Police's Android N coverage (OEM behavior can vary — e.g. NVIDIA SHIELD opens "all apps"
    instead). OK/Select → context menu confirmed anecdotally via Home Assistant community reports
    (YouTube shows a channel-context menu; Plex reveals its scrub bar) — app-specific behavior, not
    OS-guaranteed for every app.
33. **Practical pitfall, medium confidence.** A community thread (Unfolded Circle) reports real
    integration bugs where long-press was mis-detected as rapid repeated short-presses due to timing
    thresholds — worth deliberate attention when choosing this app's own press-vs-hold detection
    threshold in the UI gesture layer (Sub-goal B), not just a protocol-level concern.

## Verified facts — Roku (confirmed, Research agent 3, 2026-09-11)

16. **High confidence, official source.** Roku's own ECP developer docs
    ([developer.roku.com/dev/docs/external-control-api](https://developer.roku.com/dev/docs/external-control-api))
    confirm `keydown/<key>` and `keyup/<key>` as real, separate `POST` endpoints (port 8060, empty
    body) alongside `keypress/<key>`. `keypress` is documented as equivalent to a `keydown` +
    `keyup` pair in one call.
17. **High confidence, official source.** A **single** `keydown` call sustains the hold — Roku's
    own doc example issues one `keydown/left`, sleeps 10 seconds, then one `keyup/left`, described
    as "holding the Left key for ten seconds." The client does **not** need to resend `keydown`
    repeatedly; the TV/firmware auto-repeats navigation on its own for the whole window between the
    single down and the eventual up. Only the release timing is the client's responsibility.
    Corroborated independently (medium confidence) by an Allonis Roku integration guide describing
    "Roku Longpress" as exactly "KeyDown, wait, KeyUp."
18. **High confidence.** Same key-name strings work across all three endpoints (`Left`, `Right`,
    `Select`, `Home`, etc., plus `Lit_<char>` for literal character input) — no separate naming
    scheme for hold vs tap.
19. **Medium-low confidence — real caveat, no official source.** No Roku-official bug report was
    found describing keydown/keyup reliability issues, and nothing TCL-specific surfaced either way.
    But an independent open-source Roku remote client
    ([Jalv13/omarchy-roku-remote](https://github.com/Jalv13/omarchy-roku-remote)) defensively
    implements a **watchdog timer that force-fires `keyup` even if the intended release event is
    lost** (e.g. dropped network call, app backgrounded mid-hold) — a real "stuck key" risk worth
    designing around regardless of root cause. **Recommend this app do the same**: any hold-tracking
    state should have a hard timeout that force-sends `keyup` if the expected release never arrives.

## Verified facts — Samsung (confirmed, Research agent 2, 2026-09-11)

20. **High confidence, real library source.** `Press`/`Release` are genuine `Cmd` values, confirmed
    directly in `xchwarze/samsung-tv-ws-api`'s `remote.py` (`SendRemoteKey.click()`/`press()`/
    `release()` static methods) — the actively-maintained library that Home Assistant's own
    `samsungtv` core integration uses as its backend. Also independently confirmed in
    `ollo69/ha-samsungtv-smart`'s `send_key(cmd="Click"|"Press"|"Release")`.
    Samsung itself has never published this endpoint's docs — confirmed reverse-engineering only,
    per a maintainer comment on the `samsung-tv-ws-api` repo.
21. **High confidence.** Payload shape is unchanged — only `Cmd` differs (`"Press"`/`"Release"`
    instead of `"Click"`); `DataOfCmd`, `Option`, `TypeOfRemote` stay identical to what this app
    already sends.
22. **High confidence.** Two independent real implementations build a `hold(key, seconds)` helper
    exactly as `press → sleep(seconds) → release` — `samsungtvws`'s `SendRemoteKey.hold()`/
    `SamsungTVWS.hold_key()` (also exposed as a CLI command) and `ha-samsungtv-smart`'s
    `hold_key(key, seconds)`. This is the same shape Roku's own `keydown`-sleep-`keyup` pattern
    uses (fact #17) — convergent design across two unrelated brands' community tooling.
23. **Medium confidence, narrow evidence.** One concrete documented real-TV behavior difference:
    holding `KEY_POWER` via Press+sleep(≥3s)+Release fully powers off a Samsung "The Frame" TV,
    versus a plain `Click` which only toggles Art Mode — shipped in `samsung-tv-ws-api` PR #9,
    later used in a Home Assistant integration per maintainer comment on PR #66. **Not confirmed:**
    continuous auto-repeat behavior (e.g. D-pad scroll) purely from an unreleased `Press` — only the
    POWER/Frame-TV case has a documented before/after. Older/simpler `samsungctl` (archived) has
    only `Click` hardcoded, confirming Press/Release is a newer/optional capability, not universal
    across all Samsung firmware generations — worth a defensive fallback-to-repeated-Click path if a
    given TV doesn't honor Press/Release.

## Verified facts — Sony Bravia / Hisense (confirmed, Research agent 5, 2026-09-11)

24. **High confidence.** Sony's own BRAVIA Professional Displays docs describe IRCC as "a control
    code that digitizes commands sent from an infrared remote control" — a discrete pulse by design,
    with no press/hold/duration concept anywhere in Sony's IRCC-IP overview or code-list pages. Two
    independent open-source clients (`pybravia`, `braviaproapi`) both expose only atomic
    single-command sends — neither implements or discusses hold/repeat anywhere in source. No
    library or doc gives a safe repeat interval for IRCC-IP specifically — the only numeric interval
    found (~45ms, "minimum three retransmits while held") describes the original physical Sony SIRC
    infrared layer, not the network protocol, and cannot be assumed to transfer. **Any repeat
    interval chosen for Sony Bravia hold-emulation is an engineering guess, not sourced prior art —
    validate empirically against real hardware (`sony_bravia_validation_matrix.md`) before shipping.**
25. **High confidence.** No VIDAA/Hisense community project (`newAM/hisensetv`,
    `Krazy998/mqtt-hisensetv`, `warrenrees/ha_vidaatv`) documents a KEY_DOWN/KEY_UP pair — every one
    sends a single bare key-name string (`KEY_UP`, `KEY_POWER`, etc.) with no native hold concept.
    **Medium confidence prior art:** `stevene1919/hisense_vidaa` (HA custom component) implements
    repeat-emulation with a **0.4s** default interval between resends — the only concrete number
    found anywhere for VIDAA, but it's an untested author default, not a measured broker rate limit
    (the same project's README notes it separately added rate-limiting/mutex locks specifically to
    avoid overwhelming the TV's MQTT broker during reconnects — confirms the broker *can* be
    overloaded, without quantifying the actual threshold).

## Verified facts — LG webOS (confirmed, Research agent 4, 2026-09-11)

26. **Medium-high confidence.** The pointer-socket protocol is plain-text (`type:value\nkey:value\n\n`,
    two trailing newlines), documented `type:` values across six independent OSS clients checked
    (`hobbyquaker/lgtv2`, `klattimer/LGWebOSRemote`, `bscpylgtv`, `PyWebOSTV`, `go-webos`, openHAB's
    lgwebos binding) are `button`, `click`, `move` (`dx`/`dy`), `scroll` (`dx`/`dy`) — none expose a
    down/up, press/release, or repeat-rate field for `button`. Every button send across every one of
    these projects is one complete atomic message. Absence across 6 independent reverse-engineering
    efforts spanning ~8 years is a strong negative signal, though LG has no public spec so an
    undocumented field can't be ruled out with total certainty.
27. **Medium confidence.** LG's own `magic_mapper` project (runs as a privileged on-device listener,
    closer to the metal than any network client could get) explicitly states key repeats are **not**
    forwarded for mapped buttons and long-presses over 1s are ignored by its interception layer —
    even a root-level on-TV listener doesn't see continuous "held" state, only a discrete final
    button event. Consistent with hold/repeat being resolved entirely inside the TV's own input
    framework, never exposed over SSAP or the pointer socket to any external client.
28. **High confidence — consistent, unresolved consensus.** Home Assistant's own `webostv`
    integration has an open, maintainer-closed-as-not-planned issue
    (`home-assistant/core#112465`, "Cannot long press webostv buttons") and an unanswered community
    forum thread asking for the same thing — no confirmed workaround exists anywhere in that
    ecosystem. The closest real-world pattern found
    (`madmicio/LG-WebOS-Remote-Control`, a Lovelace card) implements "long press" purely as **a UI
    gesture that fires one different discrete command** (e.g., long-press Home → send MENU instead)
    — not a protocol-level hold at all.
29. **High confidence.** No project found implements or recommends rapid-repeat emulation for LG
    specifically (unlike Samsung/Sony/Hisense, where at least someone attempted it). **LG genuinely
    has no native hold primitive and no established emulation prior art** — the "different single
    command on long-press-gesture" pattern (fact #28) is the only viable path for LG, not a
    repeat-based hold.

---

## Open questions (blocking Sub-goal B design work)

1. ~~Android TV — does the client need to resend anything between `START_LONG` and `END_LONG`?~~ —
   **RESOLVED**, see facts #30-33. True two-message pair, nothing sent in between; same shape as
   Roku and Samsung's hold pattern.
2. ~~Samsung — is `'Press'`/`'Release'` real and safe to use, and does the payload shape change?~~ —
   **RESOLVED**, see facts #20-23. Real, safe, payload shape unchanged except `Cmd`.
3. ~~Roku — do `/keydown/`/`/keyup/` exist in Roku's own docs, and does the TV handle duration
   itself?~~ — **RESOLVED**, see facts #16-19. Official, single `keydown` sustains the hold, client
   only controls release timing (plus a recommended watchdog timeout).
4. ~~LG — is there truly nothing, or is there an undocumented-but-real hold verb?~~ — **RESOLVED**,
   see facts #26-29. Confirmed absent across 6 independent OSS clients + LG's own on-device
   `magic_mapper` project + an unresolved HA maintainer thread. No emulation prior art either — the
   only real-world workaround pattern is firing a different discrete command on a long-press *UI
   gesture*, not a protocol-level hold.
5. ~~Sony BRAVIA / Hisense VIDAA — confirmed no hold primitive? What repeat interval, if any, do
   existing integrations use?~~ — **RESOLVED**, see facts #24-25. Both confirmed no native hold.
   Sony: no sourced repeat interval at all (would be an engineering guess). Hisense: one prior-art
   number found (0.4s in `stevene1919/hisense_vidaa`), untested against actual broker limits.
6. ~~Product/UX scope decision: ship long-press only for confirmed-native brands, or attempt
   emulation everywhere?~~ — **RESOLVED 2026-09-11, see Decisions log.** Scope is **officially
   supported only: Android TV family (incl. Sony's Google TV line, TCL Google TV), Samsung, Roku.**
   LG, Sony BRAVIA, Hisense VIDAA, and TCL legacy WiFi are explicitly **out of scope** — no
   client-side repeat emulation will be built for any of them, since none has a reliable native
   primitive and the user judged emulation "bound to break."
7. **Architecture decision — proposed 2026-09-11, awaiting user confirmation** (see Decisions log
   for the full skill-grounded derivation): a new optional `TvBrandAdapter` capability
   (`supportsKeyHold` getter + `sendKeyHold({device, command, phase: KeyHoldPhase.down|up})`,
   default `throw UnsupportedError`) mirroring the existing `supportsTextInput`/`probeConnection`
   convention exactly, overridden only by the three in-scope adapters. `RemotePressFeedback` gains
   optional `onHoldStart`/`onHoldEnd` callbacks rather than a parallel widget, wired only for the
   commands this goal targets (OK/Home/Left/Right), with a watchdog timeout forcing the "up" phase
   if the gesture's end event is ever lost. Not yet approved — per DA-7 this is a genuinely new
   pattern with no prior instance in this codebase, so it needs explicit user sign-off before any
   code is written, not just a presented recommendation.

---

## Research dispatch (this session)

Five parallel agents dispatched to verify claims #11-15 / open questions #1-5 above against primary
or authoritative sources (official protocol docs where they exist, or the actual source of the
reference open-source implementations this repo already cites elsewhere). Each was asked to report
confidence level and cite sources, following this repo's own established convention from the Sony
Bravia research spike (`goal-sony-adapter.md`'s "Verified facts" sections).

- **Agent 1 — Android TV Remote Protocol v2** hold semantics (`START_LONG`/`END_LONG` resend
  requirement; Google TV Remote app's own long-press behavior for Home/OK).
- **Agent 2 — Samsung Tizen `ms.remote.control`** `Press`/`Release` `Cmd` value verification.
- **Agent 3 — Roku ECP** `/keydown//keyup` endpoint verification against Roku's own developer docs.
- **Agent 4 — LG webOS** pointer-socket/SSAP hold mechanics.
- **Agent 5 — Sony BRAVIA IRCC-IP / Hisense VIDAA** hold-primitive verification and existing
  community emulation approaches, if any.

All five reported back this session — findings folded into "Verified facts" sections above and open
questions #1-5 resolved.

---

## Sub-goals

- [x] **A. Research spike (this doc).** Done 2026-09-11.
  - [x] A1. Direct codebase read of every adapter/transport client + every remote button widget —
        done this session, see "Verified facts — codebase" above. Deps: none. Risk: LOW. Skills:
        system-design, platform-specific-optimization.
  - [x] A2. External protocol verification via 5 parallel research agents — done this session, see
        "Verified facts — Android TV/Samsung/Roku/LG/Sony Bravia-Hisense (confirmed)" sections
        above. Deps: A1. Risk: LOW (research only, no code changes). Skills: api-design,
        dependency-safety-integration.
  - [x] A3. Synthesized agent findings into the doc + resolved open questions #1-5, with citations —
        done this session. Deps: A2.
- [x] **B. Design the press/hold contract.** Done 2026-09-11 — proposed via skill-derivation
      (`api-design`, `design-pattern-selection`, `abstraction-domain-modeling`, `clean-code-solid`,
      `correctness-validation`), approved by the user ("deferring to my software engineer skills").
      Final shape: `TvBrandAdapter.supportsKeyHold`/`sendKeyHold` (default `throw
      UnsupportedError`, mirrors `supportsTextInput`); a separate opt-in `KeyHoldCommandService`
      application port (mirrors `TransportLogReaderProvider`'s shape) rather than adding to
      `RemoteCommandService` itself, discovered necessary mid-implementation once it became clear
      every `TvBrandAdapter`/`RemoteCommandService` implementer in this codebase uses `implements`,
      not `extends` — see Decisions log for why that changed the original proposal.
      Deps: A3. Risk: MEDIUM (new cross-cutting pattern). Skills: system-design,
      abstraction-domain-modeling, api-design.
- [x] **C. Implement, brand by brand.** Done 2026-09-11. Shipped: `KeyHoldPhase` domain enum;
      `TvBrandAdapter`/`KeyHoldCommandService` capability; real implementations in
      `AndroidTvAdapter`/`TclGoogleTvAdapter`/`SonyAdapter` (via a new
      `AndroidTvTransportClient.sendKeyHold`, `START_LONG`/`END_LONG`), `SamsungAdapter` (via
      `SamsungTransportClient.sendKeyHold`, `Cmd: "Press"`/`"Release"`), `TclRokuAdapter` (via a new
      `RokuTransportClient.sendKeyHold`, dispatching to `/keydown/`/`/keyup/` under the hood);
      trivial `supportsKeyHold => false` overrides on the 4
      out-of-scope adapters (required by `implements`, not optional); `RemotePressFeedback` gained
      `onHoldStart`/`onHoldEnd` via `RawGestureDetector` + a real `LongPressGestureRecognizer`
      configured with `kRemoteHoldThreshold`, plus a `kRemoteHoldWatchdogTimeout` safety net;
      wired into `RemoteCircularDpad` (OK/Left/Right) and the generic layout-item path (Home only)
      in `remote_home_remote_grid.dart`/`remote_home_page.dart`; DI registration in
      `remote_control_di_config.dart` + `one_remote_app.dart`. Full test coverage added per brand
      (`*_test_lane_test.dart` convention) plus `brand_routed_remote_command_service_test.dart` and
      a new `remote_press_feedback_test.dart` hold-gesture group (including a real watchdog-fires
      test). `flutter analyze`: 0 issues. `dart format`: clean. `flutter test`: 804 passed, 0
      failed. Deps: B.

---

## Decisions log

- 2026-09-11: **Goal doc created.** User asked for a goals document for this feature after an initial
  research pass in-conversation (UI/dispatch architecture + per-adapter native-primitive survey, now
  in "Verified facts — codebase" above). Codebase findings written down first since they're already
  high confidence; external protocol claims from that same pass were carried into "Verified facts —
  external protocols" but explicitly flagged unconfirmed, and five parallel research agents dispatched
  same-session to verify them against primary sources before this doc's open questions are considered
  resolved.
- 2026-09-11: **Research spike complete — all 5 external protocol questions resolved.** Summary
  capability matrix, cross-referencing every fact number above:

  | Brand/protocol | Native hold primitive | Client-side work needed |
  |---|---|---|
  | Android TV (+ Sony ATV, TCL Google TV) | **Yes** — `START_LONG`/`END_LONG` (facts #3, #30-33) | Send down, track wall-clock duration, send up. Already-unused code in `android_tv_remote_messages.dart`. |
  | Samsung | **Yes** — `Cmd: "Press"/"Release"` (facts #4, #20-23) | Same down/wait/up shape; one line change from current `"Click"`. |
  | Roku | **Yes** — official `/keydown/`/`/keyup/` (facts #5, #16-19) | Same shape; add a watchdog timeout to force-release (fact #19's stuck-key risk). |
  | Sony BRAVIA IRCC-IP | **No** (facts #7, #24) | Client-side repeat emulation; no sourced safe interval — must be determined empirically against real hardware. |
  | Hisense VIDAA | **No** (facts #8, #25) | Client-side repeat emulation; 0.4s is the only prior-art number found, unvalidated. |
  | LG webOS | **No, and no viable repeat-emulation path either** (facts #6, #26-29) | Cannot truly hold. Best available substitute: map long-press to a *different single discrete command* (the one real-world pattern found, `madmicio`'s Lovelace card). |
  | TCL legacy WiFi | **No**, and structurally poor fit (fact #9) | Not recommended — fresh TCP handshake per repeated tap. |

  **Notable convergent finding:** three independently-researched brands (Android TV, Samsung, Roku)
  all use the *identical* implementation shape in their respective community tooling — one down
  message, a client-tracked `sleep(duration)`, one up message, no traffic in between (facts #17, #22,
  #30). This is strong, cross-brand evidence for what Sub-goal B's UI/dispatch contract should look
  like for the native-primitive brands, independent of any one protocol's quirks.
  **Next step at the time:** Sub-goal B blocked on the user for open questions #6 (scope) and #7
  (contract shape).
- 2026-09-11: **Open question #6 resolved — scope is officially-supported-only.** User's exact
  instruction: "only officially supported. we will not do the ones that are not supported as those
  are bound to break." Genuine ambiguity surfaced and resolved before writing this down: Samsung's
  `Press`/`Release` is **not** documented by Samsung anywhere (fact #20 — confirmed
  reverse-engineering only), so a strict "vendor published this" reading would have excluded it
  alongside LG/Sony Bravia/Hisense. Asked the user directly rather than assume either interpretation
  (per this project's own architectural-consistency practice of not silently resolving an ambiguous
  scope call) — **user chose to include Samsung**, i.e. "officially supported" means "has a real,
  reliable native primitive" (matching their stated concern, breakage risk), not literal first-party
  documentation. Final scope, fixed: `AndroidTvAdapter`, `TclGoogleTvAdapter`, `SonyAdapter`,
  `SamsungAdapter`, `TclRokuAdapter`. `LgAdapter`, `SonyBraviaAdapter`, `HisenseAdapter`,
  `TclLegacyWifiAdapter` are explicitly excluded from this goal, not deferred — per verified facts
  #24-29 none of the four has a reliable native primitive, and LG has no viable emulation path at
  all. **Next step at the time:** Sub-goal B still blocked on the user for open question #7
  (contract shape).
- 2026-09-11: **Open question #7 — proposed design, derived directly from senior-software-engineer
  skills (`api-design`, `design-pattern-selection`, `abstraction-domain-modeling`,
  `clean-code-solid`, `correctness-validation`), not yet approved.** User asked "what would software
  engineer skills dictate?" — loaded the four design-relevant skills plus their `correctness-validation`/
  `clean-code-solid` dependencies and every rule in their compact headers, then applied them:
  - `api-design`'s MF-3 (backward compatibility) + `clean-code-solid`'s ISP → no signature change to
    the live `TvBrandAdapter.sendCommand` contract; the four out-of-scope adapters get nothing new
    to implement.
  - `design-pattern-selection`'s DA-7 (consistency check) → `TvBrandAdapter`'s own doc comment
    already documents its convention for optional per-brand capabilities (default
    `throw UnsupportedError` / a `supportsX` getter, e.g. `supportsTextInput`, `probeConnection`).
    Long-press should reuse that precedent, not invent a new one.
  - `abstraction-domain-modeling`'s DA-2 → the right abstraction is a capability flag
    (`supportsKeyHold`), the same shape as `supportsTextInput`.
  - `clean-code-solid`'s DA-3 (conditional-logic placement) → the down/up-vs-unsupported branch
    belongs in each adapter, never in the UI or `BrandRoutedRemoteCommandService`, matching the
    existing separation.
  - **Proposed shape:** `TvBrandAdapter` gains `bool get supportsKeyHold => false;` and
    `Future<void> sendKeyHold({required TvDevice device, required RemoteCommand command, required
    KeyHoldPhase phase})` defaulting to `throw UnsupportedError`. Overridden by the three in-scope
    adapters: Android TV family reuses `_keyMap.payloadFor(command)` for the key code and sends
    `RemoteDirection.startLong`/`.endLong`; Samsung extends `sendKey`'s existing `Cmd` handling with
    a defaulted parameter (`'Press'`/`'Release'` vs `'Click'`) rather than a new method
    (`design-pattern-selection`'s DA-5, avoid overengineering); Roku gets two genuinely new
    transport methods (`sendKeyDown`/`sendKeyUp`) since `/keydown/`/`/keyup/` are real distinct
    endpoints, not a parameterization of `/keypress/` — this asymmetry with Android TV/Samsung is a
    justified `DA-6` pragmatic deviation, same reasoning `goal-sony-adapter.md`'s three-resolvers
    decision already used, not a consistency smell.
  - UI: `RemotePressFeedback` gains optional `onHoldStart`/`onHoldEnd` callbacks (reuses its
    existing tap-feedback animation, DRY) rather than a parallel widget, wired only for the commands
    this goal actually targets (OK/Home/Left/Right) per `DA-5`. `correctness-validation`'s PC-5 plus
    Roku's confirmed stuck-key risk (fact #19) both point to a watchdog timeout that force-fires the
    "up" phase if the gesture's end event is ever lost (e.g. app backgrounded mid-hold) — applied to
    all three brands defensively, not just Roku.
  - `TQ-1` (test coverage requirement): every new adapter method needs tests before merge, following
    this repo's established `*_test_lane_test.dart`-per-brand convention.
  - **Status: proposed, not approved.** Per `DA-7`, this is a genuinely new pattern with no prior
    instance in this codebase — explicit user confirmation is required before Sub-goal C
    implementation begins, not assumed from the skill-derivation alone.
- 2026-09-11: **User approved the proposed design** ("at this point you might know the code
  better... i'm deferring to my software engineer skills which i defined so that you have a
  guide") — read as authorization to proceed to implementation using the skill-derived design as
  the standard, trusting code-level judgment calls to the assistant. Implementation began
  immediately after.
- 2026-09-11: **Mid-implementation correction to the approved design — `KeyHoldCommandService` as a
  separate opt-in port, not an addition to `RemoteCommandService`.** Before writing any adapter
  code, confirmed via `flutter analyze` that all 9 `TvBrandAdapter` implementers in this codebase
  use `implements TvBrandAdapter`, not `extends` — meaning Dart does not inherit `TvBrandAdapter`'s
  default method bodies at all; every implementer must write out its own body for every interface
  member, even trivial ones (confirmed directly: adding `supportsKeyHold`/`sendKeyHold` to
  `TvBrandAdapter` produced exactly 9 "missing concrete implementation" compile errors, one per
  adapter). This was not analyzed in the original B design proposal. It changed the plan for
  `RemoteCommandService`, the service-layer counterpart: that interface has **9 implementers**
  (`BrandRoutedRemoteCommandService`, `DiagnosticsRecordingRemoteCommandService`,
  `InMemoryRemoteCommandService`, plus 6 hand-written test stubs for unrelated features —
  `pairing_page_test.dart`, `free_tier_device_policy_test.dart`,
  `reconnection_retry_controller_test.dart`, etc.), all via `implements`. Adding
  `supportsKeyHold`/`sendKeyHold` directly to `RemoteCommandService` would have forced all 9 to
  carry hold-related boilerplate they have nothing to do with — a real ISP violation, not a
  theoretical one. Found and reused an exact existing precedent for this situation:
  `TransportLogReaderProvider` (`lib/remote_control/application/transport_log_reader_provider.dart`)
  is already a separate `abstract interface class`, implemented only by
  `BrandRoutedRemoteCommandService`, registered as its own DI singleton pointing at the same
  `commandService` instance, and consumed by `RemoteHomePage` via an optional constructor
  parameter defaulting to a `Noop` implementation. Built `KeyHoldCommandService` /
  `NoopKeyHoldCommandService` in `key_hold_command_service.dart` as an exact mirror of that shape,
  rather than touching `RemoteCommandService` at all — zero of the 9 `RemoteCommandService`
  implementers needed any change. This is a correction to, not an abandonment of, the approved B
  design — the `TvBrandAdapter`-level contract (`supportsKeyHold`/`sendKeyHold`) shipped exactly as
  proposed; only the service-layer plumbing above it changed shape once the `implements`-everywhere
  fact was discovered.
- 2026-09-11: **Roku shipped as one `sendKeyHold(phase)` method, not two (`sendKeyDown`/
  `sendKeyUp`) as the B proposal specified.** Minor deviation, same reasoning as Android
  TV/Samsung's single-method-with-a-phase-parameter shape: `RokuTransportClient.sendKeyHold(phase:
  KeyHoldPhase)` picks `/keydown/`/`/keyup/` internally based on `phase`, keeping the public
  transport-client surface uniform across all three in-scope brands (`sendKeyHold(deviceId,
  keyCode, phase)` everywhere) even though Roku's two HTTP endpoints are genuinely distinct calls
  underneath. Simpler for every call site (`TvBrandAdapter.sendKeyHold` implementations,
  `BrandRoutedRemoteCommandService`) to reason about one method per transport, not two per brand
  for exactly one of the three. `DA-5` (avoid overengineering): no caller ever needed `sendKeyDown`
  and `sendKeyUp` addressable independently as separate methods, so the extra surface from the
  original proposal wasn't buying anything.
- 2026-09-11: **Sub-goal C complete.** `flutter analyze`: 0 issues. `dart format
  --set-exit-if-changed`: clean. `flutter test`: 804 passed, 0 failed, no regressions — new hold
  tests were added in the same pass as the minimal compile-fix stubs the interface change forced
  across 8 test files. This goal's own implementation is done; **not yet validated against real
  hardware** for any of the three in-scope brands — see "Open items" below before
  closing/retiring this doc.

---

## Open items (before this doc retires)

1. **Real-hardware validation** — nothing in Sub-goal C has been confirmed against an actual TV.
   Per this project's own established pattern (`sony_bravia_validation_matrix.md`,
   `tcl_validation_matrix.md`), a validation matrix / manual runbook for Android TV/Samsung/Roku
   long-press (OK context menu, Home recents, Left/Right scrub) would be the next step before this
   feature is considered done in the same sense Sub-goal A of `goal-sony-adapter.md` was.
2. **Android TV's `START_LONG`→OS-auto-repeat assumption (fact #31) is inference, not confirmed
   via packet capture** — worth a first-pass real-device check specifically for whether Google's
   own long-press UX (recents on held Home, scrub on held Left/Right) actually triggers correctly
   from this app's `START_LONG`/`END_LONG` pair with no traffic in between.
3. **Samsung's Press/Release is confirmed reverse-engineered, not officially documented** (fact
   #20) — real-device validation matters more here than for Android TV/Roku, since there's no
   official spec to fall back on if a specific firmware behaves differently than
   `samsung-tv-ws-api`'s reference implementation.
