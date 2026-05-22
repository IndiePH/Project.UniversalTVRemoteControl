# Samsung Physical Validation Matrix

Tracks physical Samsung validation for `TVREMOTE-49` (test lane) and
**`TVREMOTE-14`** (approval-variant scenarios), aligned with implementation
threads `TVREMOTE-44`, `TVREMOTE-38`, `TVREMOTE-41`, and unit coverage
`TVREMOTE-13`.

## Test Scope

- Discover -> pair -> remote key control
- Text-input path behavior (supported/unsupported/IME-ready states)
- Reconnect and session continuity
- Unsupported command/text flows produce UI-safe results
- **Approval variants** (`TVREMOTE-14`): first-time TV popup, stored-token reuse,
  rejection/timeout recovery UX

## Environment

- App build/commit:
- Phone model / OS:
- Network notes (AP isolation, multicast behavior):
- Runtime flags:
  - `USE_FAKE_TRANSPORTS=false`
  - `SAMSUNG_ENABLE_TEXT_INPUT=`
  - `SAMSUNG_SEND_INPUT_END_PER_TEXT=`
  - `TV_HOST_OVERRIDE=`

## Known-good Matrix

| Date | TV model | Firmware | Pairing | Keys | Text path | Reconnect | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD |  |  | pass/fail | pass/fail | pass/fail/N/A | pass/fail |  |

## Approval Variants (`TVREMOTE-14`)

Physical validation for Milestone 1 / Task 1.1 — Samsung TV-side approval
prompt behavior. Automated regression for timeout/rejection **messaging** lives
in `TVREMOTE-13` (`samsung_test_lane_test.dart`, `samsung_pairing_token_store_test.dart`);
this section records **on-TV** outcomes.

### Code under test

| Area | Path | Behavior |
| --- | --- | --- |
| Approval request + timeout | `samsung_websocket_transport_client.dart` | `requestPairingApproval`: 45s default; clears TLS pins when no stored token; sends trigger key on first connect; retries token-auth connect until deadline |
| Token + waiters | `samsung_pairing_token_store.dart` | Host-keyed token; completes/fails pending approval completers on `ms.channel.connect` frames |
| Rejection | `samsung_transport_authorization.dart`, `samsung_ws_handshake.dart` | `SamsungTransportAuthorizationException`: "Samsung TV rejected remote-control authorization." |
| Cancel / recovery | `samsung_websocket_transport_client.dart` | `cancelPairing` fails pending waiters + resets connection |
| Pairing UX | `pairing_page_sections.dart`, `pairing_page_coordinator.dart` | Busy overlay: "Waiting for TV approval..."; failures sanitized via `MessageHandler` |

### Runbook (Android APK, real Samsung TV)

Prerequisites: `USE_FAKE_TRANSPORTS=false`, phone + TV same LAN, AP isolation
off. For a clean first-time run, remove the saved Samsung device in Pairing
before scenario A.

1. **Build & install** — `flutter build apk --release` (see README "Current
   Runtime Modes").
2. **Baseline** — Pair -> Scan -> select Samsung TV -> Pair. Note whether the
   TV shows the on-screen "Allow" / remote-control prompt.
3. Run scenarios A–C below; record pass/fail + notes in the outcome table.
4. On failure, capture transport log tag `samsung_transport` (debug sheet) and
   whether retry from Pairing recovers without app reinstall.

#### Scenario A — First-time approval

| Step | Action | Expected (code contract; confirm on TV) |
| --- | --- | --- |
| A1 | Fresh pair (no prior token for this TV IP/host) | TLS endpoint pins cleared before connect (`SamsungTlsTrustStore.clearEndpoint`) |
| A2 | Pair selected device | Pairing UI shows "Waiting for TV approval..." |
| A3 | TV shows allow prompt; user taps Allow | Token stored; pairing completes; device saved; remote keys work |
| A4 | (Negative) Do not approve within ~45s | Pairing fails with message containing "Timed out waiting for Samsung TV approval" |
| A5 | Retry pairing after A4 timeout | User can scan/select again; approval prompt reappears (no stuck busy state) |

#### Scenario B — Previously approved token reuse

| Step | Action | Expected (code contract; confirm on TV) |
| --- | --- | --- |
| B1 | Complete scenario A successfully | Token persisted per host |
| B2 | Force-stop app; relaunch | Last-used device may auto-restore on Remote Home (`TVREMOTE-11` returning flow) |
| B3 | Pair same TV again (or reconnect from saved list) | Should **not** require a new TV popup if token still valid; connect uses stored token (`hasNonEmptyToken` path skips fresh approval wait) |
| B4 | Remove saved device; re-add same IP via manual add | If token still on TV/app store, pair may succeed without prompt; if TV revoked trust, falls back to scenario A |

#### Scenario C — Rejection / timeout recovery UX

| Step | Action | Expected (code contract; confirm on TV) |
| --- | --- | --- |
| C1 | Start pair; on TV prompt tap **Deny** / reject | Pairing fails; user-visible message sanitized from transport error (rejection or authorization wording) |
| C2 | Tap Pair again after C1 | New approval attempt; not permanently blocked |
| C3 | Start pair; tap **Cancel** in app (if shown) or navigate back during wait | `cancelPairing` clears waiters; no orphan busy overlay on return |
| C4 | Timeout (A4) then immediate retry | Same as C2 — recovery without reinstall |

### Approval outcome table (`TVREMOTE-14` AC)

Fill after physical runs. Status: `pass` | `fail` | `blocked` (no hardware).

| Scenario | TV model | Firmware | Date | Status | Observed UX / transport | Follow-up Jira |
| --- | --- | --- | --- | --- | --- | --- |
| A First-time approval |  |  |  |  |  |  |
| B Token reuse |  |  |  |  |  |  |
| C Rejection / timeout recovery |  |  |  |  |  |  |

### Expected gaps → follow-up issues

When a scenario **fails** on hardware but unit tests pass, open a Jira task
under `TVREMOTE-36` / `TVREMOTE-37` with:

- Scenario letter (A/B/C), TV model, firmware
- Repro steps from this runbook
- Transport log excerpt (`samsung_transport`)
- Whether `TVREMOTE-13` tests should be extended (if messaging wrong) vs
  transport fix (if TV behavior differs from contract)

**Outstanding (no physical run yet):** all three scenarios remain `blocked`
until a Samsung TV is available. Do **not** mark `TVREMOTE-14` Done in Jira
until this table has at least one `pass` row per scenario on real hardware.

## Findings (running log)

- _2026-05-22_ — **`TVREMOTE-14` runbook shipped:** approval-variant scenarios
  A–C, code-under-test map, outcome table, and follow-up template added.
  Code-review parity: transport implements first-time wait, token reuse loop,
  45s timeout strings, rejection via `SamsungTransportAuthorizationException`,
  and `cancelPairing` recovery. **Awaiting physical-device runs** to record
  pass/fail and open follow-ups for any TV-specific gaps.

## Regression Notes

- Store concise failures with reproduction hints and mitigation notes.
- Link Jira follow-ups when new issues are identified.
