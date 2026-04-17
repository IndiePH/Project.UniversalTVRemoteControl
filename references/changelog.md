# Changelog

This changelog provides a quick summary of product and implementation direction updates.
Keep entries short and append new updates at the top.

## 2026-04-18

### Changed
- Updated pairing behavior and Samsung authorization flow:
  - pairing now stays on `PairingPage` until async pairing completes (no early return to remote page)
  - pairing page now blocks user input while busy and shows a loading modal
  - Samsung pairing now triggers TV authorization prompt during pairing flow (no extra manual button press required)
  - pairing success is now gated by Samsung token-authenticated session readiness, not just initial socket connect
- Updated remote screen keyboard behavior:
  - set remote `Scaffold` to avoid body resize on IME open so keyboard overlays the app instead of pushing the layout
- Updated Samsung text-input payload flow:
  - corrected `SendInputString` payload shape (`Cmd`=base64 text, `DataOfCmd`=`base64`)
  - added IME priming event and input-end message for broader Samsung model compatibility

### Verification
- `flutter analyze` passes after transport, pairing, and UI changes
- `flutter test` passes after updating pairing status expectations and constructor wiring

### Added
- Optional Samsung transport diagnostics behind `--dart-define=SAMSUNG_TRANSPORT_DEBUG=true`:
  - logs outbound text IME frames (summarized) and inbound WebSocket messages (tag: `samsung_transport`)

### Changed (UX + docs alignment)
- Pairing page: removed the top explanatory banner; pairing rules unchanged (spec / implementation_tasks still describe active-switch + saved devices behavior)
- Layout editor: entering or leaving settings/edit mode no longer overwrites the remote `_status` line (it is not visible while editing); layout reset uses a snackbar for confirmation
- LG: device capabilities and adapter now agree that in-app text send is not implemented yet (avoids false “text sent” when nothing reaches the TV)
- Default Samsung transport is real unless `USE_FAKE_SAMSUNG_TRANSPORT=true` (documented in `README.md`)

### Synced Planning
- Refreshed `references/implementation_tasks.md` status tracker and definition of done for LG text-input follow-up
- Updated `references/product_specs.md` brand readiness row for LG vs current code reality

## 2026-04-17

### Changed
- Pairing and saved-device behavior updates:
  - switched scan path from fake provider wiring to local-network SSDP discovery service
  - clarified UX behavior: pairing a new TV switches active control; previously paired TVs remain saved
  - improved active-device remove flow confirmation UX and validated `REMOVE` regression path
  - removed seeded in-memory placeholder saved device (default startup now has no paired TV)

### Verification
- Added/updated widget coverage for:
  - full loop pass (pair discovered TV -> return -> send command)
  - active saved-device removal with typed confirmation

## 2026-04-17

### Changed
- Updated remote layout/editor baseline and status:
  - increased grid from `5x8` to `5x9`
  - updated default control coordinates to the latest requested arrangement
  - kept play/pause as a compact `1x1` control with side-by-side icons (left play, right pause)
  - updated search control to `5x1` with `4x1` text field + right-side icon action
  - restored channel/volume rocker controls in the remote canvas
  - added directional d-pad arrow padding adjustments for visual centering

### Notes
- A transient Android Gradle/Kotlin incremental cache failure was observed and resolved by rerunning the build; no product code rollback was required.

## 2026-04-17

### Changed
- Clarified `references/third_party_licenses.md` with explicit internal-only stance:
  - no third-party runtime TV-control dependencies currently used
  - tracker retained for future library evaluations and release audit traceability

## 2026-04-17

### Changed
- Updated `references/third_party_licenses.md` to remove Samsung/LG/Hisense external candidate entries.
- Set current direction to internal adapter implementations only (external libraries deferred).

## 2026-04-17

### Changed
- Updated `references/third_party_licenses.md` with production adoption gating:
  - added explicit Go/No-Go criteria
  - added Go/No-Go status column to verification log

### Notes
- All three candidate libraries remain MIT-licensed, but final adoption status is now tracked as conditional until pinned-version and technical smoke-test checks pass.

## 2026-04-17

### Changed
- Updated `references/third_party_licenses.md` with:
  - explicit "older source / use with caution" guidance
  - a verification log table for license audit tracking

### Notes
- MIT status for Samsung/LG/Hisense candidates is considered commercially compatible with notice compliance, but technical/legal verification is still required at pinned commit/version before release.

## 2026-04-17

### Added
- Added `references/third_party_licenses.md` to track external library license status and commercial-use readiness for Samsung/LG/Hisense candidates.

### Notes
- Documented that no third-party TV-control library is integrated yet; current implementation uses internal adapter stubs and router.

## 2026-04-17

### Added
- Added implementation status tracker section to `references/implementation_tasks.md` with:
  - completed items
  - in-progress items
  - next-up priorities

### Changed
- Updated planning visibility to reflect actual code progress:
  - brand adapter router + capability checks
  - safe dispatch result flow
  - pairing page with fake discovery + manual fallback
  - saved-device management and active-device removal safeguards

## 2026-04-17

### Added
- Added a living brand readiness matrix to `references/product_specs.md` for Samsung, LG, Hisense, and Android TV/Google TV.

### Changed
- Aligned Wi-Fi protocol listing with current MVP focus:
  - Samsung and LG are now explicitly MVP targets
  - Hisense listed as validation-gated MVP best-effort
  - Android TV/Google TV moved to Post-MVP expansion candidate

## 2026-04-17

### Changed
- Updated platform strategy in `references/product_specs.md` to Android MVP with iOS treated as Post-MVP.
- Updated MVP brand focus to Samsung, LG, and Hisense (hardware-available-first testing approach).
- Marked cloud pairing as Post-MVP exploration.
- Updated development phases and MVP scope to reflect Samsung/LG first and Hisense validation gate.

### Notes
- Added guidance to prefer stable open-source/protocol adapters where available:
  - Samsung Tizen WebSocket paths exist
  - LG webOS WebSocket paths exist
  - Hisense VIDAA control exists but is less standardized and requires validation

### Synced Planning
- Updated `references/implementation_tasks.md` milestones and definition of done to align with Samsung/LG/Hisense-first execution and iOS-safe architecture planning.

## 2026-04-17

### Changed
- Removed team workload split content from `references/product_specs.md` per scope simplification.
- Renumbered following sections to keep spec numbering consistent.

## 2026-04-17

### Changed
- Refined `references/product_specs.md` future expansion scope to remain TV-only.
- Marked non-TV remotes and broader smart-home scope as out-of-scope for this project.

### Notes
- Non-TV expansion ideas can be pursued in a separate project.

## 2026-04-17

### Added
- Added text input keyboard capability to `references/product_specs.md` for TV search/forms.
- Included text-input verification in first-time setup flow.
- Added technical note for protocol-level text input support and fallback behavior.

### Synced Planning
- Updated `references/implementation_tasks.md` to include keyboard UI and command payload support for text input.
- Updated definition of done to include text input support on compatible TVs.

## 2026-04-17

### Added
- Created `references/implementation_tasks.md` as a living implementation plan derived from `references/product_specs.md`.
- Defined milestone flow:
  - Foundation
  - Vertical Slice (Android TV first)
  - Expansion (Samsung + multi-device)
  - Polish
- Added cross-cutting tracks for testing, telemetry, and platform considerations.

### Notes
- `references/product_specs.md` remains the current source of truth.
- Plan is intentionally flexible and expected to change during development.
- Prioritization favors speed-to-market with incremental, working slices.

### Next Suggested Update Trigger
- Update this changelog when:
  - MVP scope shifts
  - protocol/device support changes
  - milestone order changes
  - acceptance criteria are tightened or relaxed
