# Samsung Physical Validation Matrix

Tracks physical Samsung validation for `TVREMOTE-49` (test lane), aligned with implementation threads `TVREMOTE-44`, `TVREMOTE-38`, and `TVREMOTE-41`.

## Test Scope

- Discover -> pair -> remote key control
- Text-input path behavior (supported/unsupported/IME-ready states)
- Reconnect and session continuity
- Unsupported command/text flows produce UI-safe results

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

## Regression Notes

- Store concise failures with reproduction hints and mitigation notes.
- Link Jira follow-ups when new issues are identified.
