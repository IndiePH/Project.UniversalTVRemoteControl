# Changelog

This changelog provides a quick summary of product and implementation direction updates.
Keep entries short and append new updates at the top.

## 2026-04-25

### Changed
- Introduced `get_it` DI container with `IDiConfig`/`DiBootstrap` pattern; split env-specific DI configs; removed transport concepts from presentation layer
- Registered transport clients in DI; collapsed duplicate host resolvers
- Introduced `Result` base class (`lib/remote_control/application/result.dart`) as the standard return type for all operation results; `CommandDispatchResult` extends it with `CommandOutcome` enum and `getOutcome()`
- Added `MessageHandler.sanitize` for env-aware error verbosity (hides exception detail in production)
- Replaced `sendKey` if/else chain with `TransportCommand`/`TransportCommandFactory` Command pattern; unified toggle state handling
- Generalized `TransportLogReader` as an application-layer port with `NoopTransportLogReader` default; unified Samsung WebSocket `_connectWith` method
- Made `HisenseAdapter.transportClient` required; consolidated `TVBrand` properties
- Deleted duplicate `SamsungKeyMapper.keyCodeFor`; relocated `formatTwoDigits` to `lib/utils` to fix downward layer dependency
- refactor - renamed hisense related method in pairing_page_coordinator.dart

### Added
- Unit tests for strategy map routing in `BrandRoutedRemoteCommandService`
- Wire FlutterError.onError and runZonedGuarded in main.dart
- Per device settings and capabilities. see references/guide-adding-protocol-variant.md
- soft-restart app on use fake toggle

### Conventions
- DI configuration and runtime are now decoupled: `IDiConfig` implementations declare bindings; `DiBootstrap` selects configs by `AppEnvironment`; remote control bindings live in `lib/remote_control/configurations/remote_control_di_config.dart`
- `Result` (`lib/remote_control/application/result.dart`) is the abstract base for all operation results; use `Result.success()` / `Result.failure()` named constructors; consumers use `MessageHandler.sanitize(result)` for safe display strings

## 2026-04-24

### Changed

- Reorganized lib directory structure
  - refactor(structure): flatten lib/ to feature-named top-level dirs (TVREMOTE branch-1)
  - Remove lib/src/ wrapper and lib/src/features/ nesting. Move:
    - lib/src/app/ → lib/app/
    - lib/src/features/remote_control/ → lib/remote_control/
    - lib/src/theme/ → lib/theme/
    - Mirror test/lib/src/features/remote_control/ → test/lib/remote_control/.

## 2026-04-23

### Added

- feature: LG remote adapter [TVREMOTE-39,TVREMOTE-42, TVREMOTE-45 TVREMOTE-47] (PR #2)
- remove Real or real_ prefix in class/file names (it is assumed real unless named with mock or fake)

## 2026-04-20

### Changed
- Workspace hygiene (**TVREMOTE-1**): root `.gitignore` ignores `__pycache__/`; `references/implementation_tasks.md` Status Tracker records verification of existing ignore rules for `.dart_tool/`, `build/`, platform `Flutter/ephemeral`, and clean diffs for tracked `linux/flutter/generated_plugins.cmake` and `windows/flutter/generated_plugins.cmake`.
- Saved-device fallback test coverage (**TVREMOTE-8**): widget tests now cover active-device removal fallback and non-active last-used removal fallback behavior.
- Transport abstraction follow-up (**TVREMOTE-52**, **TVREMOTE-53**): added shared transport marker + required event stream contracts and wired standardized transport events across Samsung/Hisense fake+real clients.
- Onboarding/troubleshooting guidance (**TVREMOTE-17**): pairing page now exposes a non-intrusive top-right help action (`?`) that opens permission/network and "cannot find TV" guidance, with corresponding widget coverage.
- Layout editor SRP pass: `RemoteLayoutEditor` delegates to `RemoteLayoutEditorGridGeometry`
  (cell sizing + occupancy + validation footprints), `RemoteLayoutEditGridPainter` (grid lines),
  `RemoteLayoutEditorItemPreview` (dpad/rocker/icon tiles), and `RemoteLayoutEditorDragSession`
  (anchors, hover highlight, drop resolution wiring); the stateful widget keeps the `Stack` /
  `DragTarget` / `Draggable` tree and header chrome.
- Samsung real transport SRP pass: `RealSamsungTransportClient` now composes
  `RealSamsungPairingTokenStore` (host token + TV-approval waiters),
  `RealSamsungRemoteTextSession` (IME / app-context state + `watchRemoteTextInputReady`),
  `RealSamsungTransportLogging` (logcat + file outbound summaries),
  `RealSamsungWsHandshake` (connect completer), and `samsung_transport_authorization.dart`;
  socket open/bind/close and outbound key/text framing stay in the client.
- Remote-home SRP decomposition pass:
  - extracted focused presentation widgets from `RemoteHomePage`:
    `RemoteTextEntrySheet`, `RemoteHomeStatusPanel`, `RemoteHomeAppBarActions`,
    `RemoteHomeDebugSheet`, `RemoteHomeRemoteGrid`, and `RemoteHomeActions`
  - extracted keyboard-availability policy into
    `remote_keyboard_availability.dart` (`RemoteKeyboardAvailability`) and
    kept a shared user-facing unavailable message + concise debug log mapping
  - behavior is preserved; refactor reduces `RemoteHomePage` UI/build concerns
- Pairing-page SRP decomposition pass:
  - `PairingPageCoordinator`, `PairingPageData`, `PairingPageDialogs` (including Hisense PIN prompt),
    `PairingPageViewState`, and `pairing_page_sections.dart` (`PairingSavedDevicesSection`,
    `PairingDiscoveryList`, `PairingManualAddSection`, `PairingBusyOverlay`, `PairingActionButton`)
  - `RemoteActionButton` renamed to `PairingActionButton` and colocated with pairing sections
- Layout editor: drag/drop and swap resolution live in `RemoteLayoutDropResolver` (`remote_layout_drop_resolver.dart`); swap keeps the dragged control at the dropped cell and chooses a non-overlapping footprint-aware placement for the displaced control (direction-prioritized edge candidates around moved/origin footprints).
- Layout editor: removed swap-result snackbars and the copy-last-drag debug header button.
- Docs sync:
  - updated `references/implementation_tasks.md` status tracker + SRP checklist
  - reformatted `references/implementation_tasks.md` with Markdown task lists across Status Tracker, Next Up, milestone backlog, brand-default rules, suggested execution order, definition of done, and final release gate; added a short checklist legend at the top of the plan
  - updated `references/product_specs.md`, `references/universal-tv-remote-info-and-req.md`, and `references/compliance-and-release-requirements.md` to point readers at the checklist-style Status Tracker / Final Release Gate
  - updated `references/goal-oneremote-lib-review.md` Task 3 follow-up note

### Verification
- `dart analyze` on touched layout files and `flutter test` pass after the updates.
- `dart analyze` on touched remote-home and pairing refactor modules passes.
- `dart analyze` (whole project) after Samsung transport partition passes.
- `dart analyze` + `flutter test test/widget_test.dart` after layout editor SRP split pass.
- `flutter test test/widget_test.dart` passes with saved-device removal fallback coverage (active-device removal fallback and non-active last-used removal without REMOVE guard).

## 2026-04-19

### Changed
- Remote app bar controls were clarified:
  - layout edit uses a pencil/check affordance (`Edit layout` / done)
  - debug options moved under a dedicated cog settings action
- Added runtime debug transport override (no rebuild needed):
  - settings sheet can switch fake vs real transport/discovery wiring
  - selected mode persists in `SharedPreferences` and overrides compile-time default when set
- Completed April 2026 lib review dedupe follow-ups:
  - Task 4: brand capabilities now centralized via `TvBrand.defaultCapabilities`
  - Task 5: shared `formatTwoDigits` helper used by both remote and pairing timestamp rendering

### Verification
- `flutter analyze lib` and `flutter test test/widget_test.dart` pass after task updates.

## 2026-04-18

### Added
- Dart documentation convention: `///` class/type purpose where helpful; targeted comments for non-obvious logic, algorithms, and protocol/platform behavior.
- `flutter_multicast_lock`: hold an Android Wi‑Fi multicast lock for the SSDP scan window so M-SEARCH responses on `239.255.255.250` are less likely to be dropped on real devices/APKs.

### Changed
- `SsdpDeviceDiscoveryService`: broader Hisense SSDP hints (`hiview`, `NT` in header probe), extra M-SEARCH `urn:schemas-upnp-org:device:MediaServer:1`; class doc notes Android multicast behavior.
- Planning/docs: `references/implementation_tasks.md` status tracker, `README.md` discovery note, `references/product_specs.md` Wi‑Fi discovery bullet, `references/third_party_licenses.md` for `flutter_multicast_lock`.

### Verification
- `flutter analyze` and `flutter test` pass after multicast-lock integration.

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
- Default real transports are used unless `USE_FAKE_TRANSPORTS=true` (documented in `README.md`)

### Synced Planning
- Refreshed `references/implementation_tasks.md` status tracker and definition of done for LG text-input implementation
- Updated `references/product_specs.md` brand readiness row for LG vs current code reality
- Re-aligned planning to Samsung/LG/Hisense parallel brand-specific tracks
- Added a final release legal/compliance gate in `references/implementation_tasks.md`:
  - license/attribution pass
  - go/no-go record in `references/third_party_licenses.md`

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

