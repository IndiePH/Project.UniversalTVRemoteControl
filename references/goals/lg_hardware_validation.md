# LG Hardware Validation

Covers SG-5 physical validation from `references/goals/goal-lg-remote.md`.

---

## T-5.1 · Physical Smoke Test

| Checklist | Result |
|---|---|
| SSDP discovery finds the LG TV | ✅ |
| Pairing prompt appears on TV screen; accepting stores the client-key | ✅ |
| Power, volume up/down, dpad commands visibly reach the TV | ✅ |
| Cold-restart reconnection works without re-prompting | ✅ |
| Model, firmware, and webOS version recorded below | ⬇️ |

### Device Under Test

| Field | Value |
|---|---|
| Model name | <!-- e.g. OLED55C3PSA --> |
| Firmware / software version | <!-- e.g. 03.35.30 --> |
| webOS version | <!-- e.g. webOS 23 (7.x) --> |
| Screen size / year | |

> **How to find:** Settings (gear icon) → About This TV on the LG TV.

---

## T-5.2 · Text-Input / IME Validation

| Checklist | Result |
|---|---|
| `insertText` injects text into a focused search field | ✅ |
| `sendEnterKey` triggers search | ✅ |
| Model recorded as known-good for IME | ✅ |

**IME status:** `LG_ENABLE_TEXT_INPUT` is not flag-gated — LG `supportsTextInput` and
`DeviceCapability.textInput` are unconditionally enabled following T-5.2 passing.

---

## Notes

<!-- Any quirks, firmware-specific behaviour, or edge cases observed during validation. -->
