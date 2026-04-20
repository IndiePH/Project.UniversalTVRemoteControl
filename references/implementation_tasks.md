# OneRemote — Implementation Tasks (Living Plan)

**Naming:** See `references/product_specs.md` (title block).

Living plan derived from `references/product_specs.md`—update both when scope shifts.

**Checklists:** Under **Status Tracker**, `[x]` marks work recorded as done in this plan; `[ ]` marks remaining. Lower sections (**Milestones**, **Cross-Cutting**) use `[ ]` as structured backlog lines that may still overlap the tracker—treat the **Status Tracker** as the current narrative for shipped vs in-flight work.

## Jira (project TVREMOTE)

- **TVREMOTE-36** — Per-brand TV adapters and transports (**implementation** epic; structured for additional OEMs later).
- **TVREMOTE-37** — Per-brand TV adapter and transport **testing** epic (Samsung / LG / Hisense lanes today).
- **Implementation** tasks under TVREMOTE-36 include **TVREMOTE-38**–**TVREMOTE-48** (refine adapters, text-input, physical validation, LG/Hisense pairing wiring). **TVREMOTE-7**, **TVREMOTE-14**, and **TVREMOTE-18** are parented under TVREMOTE-36.
- **Testing** tasks under TVREMOTE-37: **TVREMOTE-49** (Samsung), **TVREMOTE-50** (LG), **TVREMOTE-51** (Hisense); **TVREMOTE-13** is parented under TVREMOTE-37. Unsupported-flow test scope from former **TVREMOTE-16** is folded into those three lanes.
- Umbrella issues superseded by this split (historical, **Done** in Jira): **TVREMOTE-25**, **TVREMOTE-21**, **TVREMOTE-9**, **TVREMOTE-10**, **TVREMOTE-16**.

## Status Tracker (Current)

### Completed
- [x] Workspace hygiene baseline (`TVREMOTE-1`):
  - [x] Verified generated/transient artifacts are excluded by repo/platform `.gitignore` rules (`.dart_tool/`, `build/`, platform `Flutter/ephemeral`, plugin registrants, local gradle/IDE outputs)
  - [x] Added root `__pycache__/` ignore to prevent incidental `.cursor` Python cache churn
  - [x] Verified tracked generated plugin glue files remain intentional and clean (`linux/flutter/generated_plugins.cmake`, `windows/flutter/generated_plugins.cmake` show no diff)
- [x] Milestone 0 / Task 0.1:
  - [x] Established layered structure (`presentation` / `application` / `data` / `domain`)
  - [x] Added extensible brand adapter contracts and router-based dispatch
- [x] Milestone 0 / Task 0.3:
  - [x] Added core entities and contracts:
    - [x] `TvDevice`, `TvBrand`, `RemoteCommand`, `DeviceCapability`, `ConnectionState`
    - [x] command dispatch result model and service interfaces
- [x] Milestone 1 / Task 1.3 (partial):
  - [x] Implemented remote surface with custom controls:
    - [x] power, mute, d-pad + OK, channel rocker, volume rocker
    - [x] text input field + send action
    - [x] search/keyboard layout control stays interactable when unpaired or when remote text is unavailable: same `No device selected.` toast as other keys when there is no active device; unsupported text input or IME-not-ready uses shared `_keyboardUnavailableMessage` ("Remote keyboard can't be used on this screen or with this TV.") for toast and status row, with `debugPrint` lines tagged `keyboard press:` / `keyboard send:` plus reason and `device.id`
  - [x] Added responsive sizing fixes for control cluster
- [x] Milestone 1 / Task 1.4 (partial):
  - [x] Implemented command pipeline with brand-specific routing
  - [x] Added adapter capability checks (`supportedCommands`, `supportsTextInput`)
  - [x] Added non-throwing dispatch results for UI-safe error handling
- [x] Milestone 1 / Task 1.2 (partial):
  - [x] Added pairing screen with:
    - [x] scan flow wired to local-network SSDP discovery
    - [x] manual brand + IP add
    - [x] IPv4 validation
    - [x] recent manual IP shortcuts
    - [x] saved device quick-reconnect section
    - [x] remove saved device flow (with active-device extra confirmation)
    - [x] pairing behavior per spec (successful new pair becomes active; saved devices persist until removed); top-of-page pairing banner removed from UI
  - [x] Moved pairing persistence and final success decision into pairing flow:
    - [x] pairing page now remains visible until pairing attempt finishes
    - [x] user input is blocked during pairing busy state
    - [x] page only returns after successful pairing completion
- [x] Milestone 1 / Task 1.5 (partial):
  - [x] Persist/select last used device
  - [x] Track and surface `lastSuccessfulPairingAt` metadata
  - [x] Removed seeded in-memory placeholder saved device (app now starts with no paired TV by default)
- [x] Milestone 1 / Task 1.1 (partial):
  - [x] Samsung pairing handshake reliability improvements:
    - [x] trigger TV approval popup during pairing (no first-command workaround)
    - [x] require token-authenticated Samsung session before treating pairing as successful
  - [x] Samsung WSS TLS trust-on-first-use (TOFU) hardening:
    - [x] queue fingerprints seen during TLS for `host:8002`, commit only after a successful WSS channel handshake; abandon pending data when connect/handshake fails (covers multi-cert / chain quirks and half-failed attempts)
    - [x] clear stored pins for that endpoint when starting Samsung pairing so stale pins or TV cert changes cannot block re-pairing after TLS work
  - [x] Hisense pairing UX fallback:
    - [x] if initial pair attempt fails, pairing flow now offers a 4-digit TV PIN dialog
    - [x] entered PIN is submitted through the adapter/service pairing-code path before final failure
    - [x] invalid PIN now shows a retry fallback loop; temporary accepted dev PIN is `1234` (fake + real transport paths)
- [x] Milestone 1 / Task 1.4 (partial):
  - [x] Corrected Samsung text-input command sequence:
    - [x] fixed `SendInputString` payload format
    - [x] added IME priming and explicit input-end send
  - [x] LG: discovery/manual device capabilities and `LgAdapter.supportsTextInput` aligned (no in-app text send until webOS text transport exists)
- [x] Milestone 3 / Task 3.1 (partial):
  - [x] Updated remote keyboard behavior so IME overlays remote screen instead of pushing layout upward
  - [x] Added settings-driven grid layout editor with drag/drop + swap behavior
  - [x] Added layout persistence and default-layout reset flow
  - [x] Fixed multi-cell drag anchor behavior for d-pad (grab-point independent)
  - [x] Added search-input composite layout item and updated it to `5x1` (`4x1` text + right icon action)
  - [x] Restored channel/volume rocker controls and aligned play/pause visual as compact `1x1` control (left play icon + right pause icon)
  - [x] Added directional visual padding tuning for d-pad arrows (up/down/left/right)
  - [x] Increased editable/control grid from `5x8` to `5x9`
  - [x] Updated default control coordinates for the latest baseline layout
  - [x] Layout editor: toggling edit mode no longer overwrites `_status` (status row is not shown while editing); layout reset uses a snackbar for visible confirmation
  - [x] Layout editor drag/drop resolution extracted to `RemoteLayoutDropResolver` (`remote_layout_drop_resolver.dart`) so the editor widget stays UI-focused
  - [x] Swap behavior: moving item stays at the dropped anchor cell; displaced control uses footprint-aware placement (validation footprints for dpad `3x3`, volume/channel `1x3`, others from item size) with edge-adjacent candidates ordered **toward the moving control’s original direction**, then opposite, then other adjacents; swap is rejected when no placement avoids overlap with unrelated controls
  - [x] Removed swap-result snackbars and the “copy last drag/drop log” debug button from the layout editor header
  - [x] SRP decomposition (remote + pairing presentation): `RemoteHomePage` delegates to `RemoteTextEntrySheet`, `RemoteHomeStatusPanel`, `RemoteHomeAppBarActions`, `RemoteHomeDebugSheet`, `RemoteHomeRemoteGrid`, `RemoteHomeActions`, and `RemoteKeyboardAvailability`; `PairingPage` delegates to `PairingPageCoordinator`, `PairingPageData`, `PairingPageDialogs`, `PairingPageViewState`, and `pairing_page_sections.dart` (see SRP checklist)
  - [x] SRP decomposition (Samsung real transport): `RealSamsungTransportClient` orchestrates `RealSamsungPairingTokenStore`, `RealSamsungRemoteTextSession`, `RealSamsungTransportLogging`, `RealSamsungWsHandshake`, and `samsung_transport_authorization.dart` (socket lifecycle + wire-up remain in the client; see SRP checklist)
  - [x] SRP decomposition (layout editor): `RemoteLayoutEditor` delegates grid geometry to `RemoteLayoutEditorGridGeometry`, background lines to `RemoteLayoutEditGridPainter`, cell previews to `RemoteLayoutEditorItemPreview`, and drag/drop session state to `RemoteLayoutEditorDragSession` (see SRP checklist)
  - [x] Presentation theming: remote/pairing/layout-editor widgets under `presentation/` no longer use ad-hoc `Colors.*` / hex for remote chrome; values live on `AppColors` (`remoteGlyphOnRemote`, `remotePowerFill`, `remoteActionSuccess*`, `layoutEditorDrop*`, `pairingModalBarrier`, `pairingBusyOnCard`, etc.) with dark-theme literals aligned to prior behavior
  - [x] **SRP Refactor Checklist (Tracked)** is fully complete (all items checked)
- [x] Developer ergonomics:
  - [x] README "Current Runtime Modes": default **real** Samsung + Hisense transports for APK/physical-TV testing; fake transports opt-in via dart-define; host overrides documented; Samsung log tag `samsung_transport` (see README)
  - [x] Implementation plan: **Brand transport defaults** section (real-by-default policy; do not regress)
  - [x] Dart documentation convention: public types lead with `///` stating purpose/role; add brief `//` or `///` for non-obvious algorithms, protocol steps, platform behavior, and invariants (not line-by-line narration)
- [x] Milestone 1 / Task 1.1 (discovery hardening):
  - [x] Android APK SSDP: acquire Wi‑Fi **multicast lock** for the scan window (`flutter_multicast_lock`); manifest already declared `CHANGE_WIFI_MULTICAST_STATE` / `ACCESS_WIFI_STATE` / `INTERNET` — runtime lock was the missing piece for reliable multicast receive
  - [x] Hisense-oriented SSDP tuning: extra M-SEARCH `urn:schemas-upnp-org:device:MediaServer:1`, include `NT` in fingerprint probe, match `hiview` where firmware omits `hisense`/`vidaa` in headers
  - [x] Note: community Hisense MQTT docs (e.g. mqtt-hisensetv) assume **manual IP** + port `36669`; SSDP remains best-effort for VIDAA/DLNA fingerprints

### In Progress
- [ ] Milestone 1 / Task 1.6:
  - [x] Basic widget test coverage is in place
  - [x] Added full-loop widget pass:
    - [x] pair to newly discovered TV
    - [x] return to remote
    - [x] send command via remote control
  - [x] Added active-device remove confirmation regression coverage (`REMOVE` path)
  - [x] Added pairing flow regression updates for moved pairing persistence/flow control
  - [ ] Broader scenario tests and network edge-case validation pending
- [ ] Milestone 1 / Task 1.1:
  - [ ] Broaden physical-device validation for Samsung approval/pairing variants:
    - [ ] first-time approval
    - [ ] previously approved token reuse
    - [ ] rejection/timeout recovery UX
  - [ ] Re-validate **Hisense discovery on Android APK** after multicast-lock change (empty scan vs AP isolation vs SSDP headers); consider optional fallback discovery (e.g. guided manual IP / `TV_HOST_OVERRIDE`, future port `36669` sweep) if SSDP still misses hardware
- [ ] Milestone 3 / Task 3.1:
  - [ ] Continue usability polish for edit mode visual affordances and small-screen readability

### SRP Refactor Checklist (Tracked)
- [x] Extract keyboard-availability policy out of `_RemoteHomePageState` into a focused helper (`remote_keyboard_availability.dart`) and route keyboard press/send guards through it.
- [x] Split `RemoteHomePage` into page-shell + dedicated widgets/handlers for remote grid, pairing/debug actions, and text-entry sheet flow.
  - [x] Implemented via extracted components/helpers: `RemoteTextEntrySheet`, `RemoteHomeStatusPanel`, `RemoteHomeAppBarActions`, `RemoteHomeDebugSheet`, `RemoteHomeRemoteGrid`, `RemoteKeyboardAvailability`, and `RemoteHomeActions`.
- [x] Split `PairingPage` orchestration from widget rendering (scan/reconnect/manual pair handlers vs UI sections).
  - [x] Implemented via `PairingPageCoordinator`, `PairingPageData`, `PairingPageDialogs`, `PairingPageViewState`, and `pairing_page_sections.dart` (`PairingSavedDevicesSection`, `PairingDiscoveryList`, `PairingManualAddSection`, `PairingBusyOverlay`, `PairingActionButton`).
  - [x] Hisense PIN dialog UI builder is now delegated through `PairingPageDialogs.promptHisensePairingPin`.
- [x] Partition `RealSamsungTransportClient` into focused collaborators (socket/session lifecycle, pairing/token flow, IME/text protocol, transport logging).
- [x] Break `RemoteLayoutEditor` interaction/painter logic into smaller units with explicit responsibilities.

### Next Up
- [ ] Run parallel per-brand validation tracks (Samsung, LG, Hisense):
  - [ ] complete pairing verification and physical-device command validation per brand
  - [ ] confirm SSDP scan finds expected TVs on common home routers (multicast + client isolation)
- [ ] Connect pairing output to real protocol handshake/verification per non-Samsung brands
- [ ] Expand tests:
  - [ ] pairing success/failure paths
  - [ ] Samsung approval timeout/rejection handling paths
  - [ ] adapter capability unsupported flows
  - [ ] saved-device remove/last-used fallback paths
- [ ] Implement missing per-brand text-input transports and re-enable capability flags after validation
- [ ] Add focused widget tests for:
  - [ ] drag/drop swap behavior (including multi-cell items and resolver rejection vs accept paths)
  - [ ] layout persistence and default reset behavior
  - [ ] `5x9` default layout occupancy constraints (no overlaps)

## Planning Notes

- Current source of truth: `references/product_specs.md`
- Delivery principle: speed to market over perfection
- Initial implementation focus:
  - Flutter app architecture (`product_specs.md` §1 for platform/release)
  - Wi-Fi control first
  - Samsung/LG/Hisense parallel compatibility tracks based on available hardware
- Scope can change as we learn from implementation and testing.
- **Target launch:** **End of May 2026**; shipping earlier is welcome if the build is ready.

## Team & work split (two people, agent-assisted)

**Shape:** Two-person team; both use AI agents (**Cursor** vs **Claude** as the primary assistant in each lane). **Brand-scoped code** reduces merge overlap (each person owns distinct adapter/transport files). **Shared surfaces** (`one_remote_app.dart`, router, `pairing_page.dart` shell, `brand_routed_remote_command_service.dart`) will still conflict sometimes—that is **expected**; coordinate with small, frequent merges or explicit handoff.

| Lane | Primary owner | Focus |
| --- | --- | --- |
| **A — Cursor** | UI / presentation + Samsung & Hisense | `lib/**/presentation/**` (remote, pairing, layout editor, shared remote widgets), app theme/shell, UX polish. **Brand code:** **Samsung** and **Hisense** — `samsung_adapter.dart`, `samsung/**`, `hisense_adapter.dart`, `hisense/**`, Hisense/Samsung pairing and command paths, Hisense-related discovery fingerprints where tied to those adapters. |
| **B — Claude** | Docs & reference artifacts + LG | `references/**` (specs, gap analysis, compliance notes, review-style writeups like the former **library** branch), changelog alignment, proposed tasks in `references/goal-oneremote-lib-review.md`. **Brand code:** **LG** only — `lg_adapter.dart`, LG webOS transport/pairing work. |

**Rules of thumb**

- Touch **only** your brand’s adapter/transport tree when changing protocol behavior; ping before editing the other person’s brand files.
- **Shared** layers (domain contracts, `TvBrand`, command dispatch): either owner may propose changes—prefer a short sync or sequential PRs to avoid silent drift.
- **Docs (B)** should not block **code (A)** on the critical path; ship doc updates as parallel PRs.
- Revisit this split if load is uneven (e.g. Samsung+Hisense + UI on **A** vs LG + docs on **B**).

## Brand transport defaults (physical TV & APK) — do not regress

**Policy:** For every brand where a **real** network transport exists in code, the **default** `OneRemoteApp` wiring must use that real implementation (`bool.fromEnvironment(..., defaultValue: false)` for fake toggles). Release and internal APK builds should **not** require extra `--dart-define` flags to talk to a real TV on the LAN.

**Rationale:** The primary validation surface is an APK on a phone hitting a physical TV. Defaulting to fake transport silently hides integration bugs.

**Concrete rules:**

- [ ] **Global fake toggle only:** Use a single flag `USE_FAKE_TRANSPORTS` (default `false`) to switch all adapters to fake transports for offline/lab work.
- [ ] **Samsung/Hisense default:** When `USE_FAKE_TRANSPORTS` is `false`, wire `SamsungAdapter` to `RealSamsungTransportClient` and `HisenseAdapter` to `RealHisenseTransportClient`.
- [ ] **LG and future brands:** When a real transport exists, follow the same global toggle behavior — do not introduce per-brand fake flags.
- [ ] **New brands / transports:** Copy this pattern: one global fake switch for test doubles; real by default for APK testing.
- [ ] **Documentation:** Keep `README.md` “Current Runtime Modes” in sync whenever transport toggles or host overrides change.

**Review trigger:** Any PR that touches `one_remote_app.dart` adapter factories or introduces a new `Fake*Transport` must confirm defaults still favor real transports for APK testing.

## Milestone 0 - Project Foundation

### Task 0.1 - Establish architecture and module boundaries
- [ ] Define app layers: presentation, domain, data, device communication.
- [ ] Create contracts for remote commands and device sessions.
- [ ] Decide state management approach and dependency wiring pattern.
- [ ] Document extension points for adding new TV protocols.

### Task 0.2 - Setup environment and quality baseline
- [ ] Confirm Flutter project settings and lint/test configuration.
- [ ] Add CI checks for format, analyze, and tests.
- [ ] Add app flavor/config placeholders for debug and release.

### Task 0.3 - Define shared domain models
- [ ] Create core entities:
  - [ ] TV device
  - [ ] Device capability
  - [ ] Remote command
  - [ ] Connection state
  - [ ] Saved device profile
- [ ] Define serialization contracts for local persistence.

## Milestone 1 - Vertical Slice (Samsung + LG + Hisense)

### Task 1.1 - Implement Samsung/LG/Hisense discovery
- [ ] Build local network discovery flow for Samsung, LG, and Hisense targets.
- [ ] Show discovery results with loading, empty, and error states.
- [ ] Add retry behavior and timeout handling.

### Task 1.2 - Implement manual pairing flow
- [ ] Build device selection and pairing screen flow.
- [ ] Validate and persist successful pairing credentials.
- [ ] Add user-facing error states for failed pairing attempts.

### Task 1.3 - Build minimal remote control surface
- [ ] Implement controls:
  - [ ] Power
  - [ ] Volume up/down
  - [ ] D-pad + OK
  - [ ] Back/Home
  - [ ] Text input keyboard for search/forms
- [ ] Wire controls to Android TV command adapter.
- [ ] Wire controls to Samsung/LG/Hisense command adapters.
- [ ] Provide immediate press feedback (visual + optional haptic hook).

### Task 1.4 - Build command execution pipeline
- [ ] Create unified `sendCommand(deviceId, command)` service.
- [ ] Add command result mapping (success, timeout, unavailable).
- [ ] Add support for text input command payloads for compatible protocols.
- [ ] Add lightweight logging hooks for command failures.

### Task 1.5 - Persist and restore one saved device
- [ ] Save paired device locally.
- [ ] Auto-reconnect to last used device on app relaunch.
- [ ] Handle stale/invalid session recovery paths.

### Task 1.6 - Validate end-to-end vertical slice
- [ ] Verify first-time flow:
  - [ ] discover -> pair -> remote control -> save device
- [ ] Verify returning flow:
  - [ ] app launch -> auto-connect -> immediate remote use
- [ ] Add integration/widget tests for critical paths.

## Milestone 2 - Expansion (Multi-device + compatibility hardening)

### Task 2.1 - Add/validate per-brand protocol adapters
- [ ] Implement/refine Samsung, LG, and Hisense connection and command transports where gaps remain.
- [ ] Map shared command set to brand-specific commands where supported.
- [ ] Add protocol-specific error handling and reconnection behavior.

### Task 2.2 - Upgrade discovery and device type identification
- [ ] Distinguish supported device brands in discovery results.
- [ ] Route pairing flow to the correct protocol adapter.
- [ ] Add explicit "limited support" messaging for partially supported models/protocols.

### Task 2.3 - Implement multi-device management
- [ ] Save multiple TVs.
- [ ] Add device switcher and last-used device tracking.
- [ ] Add edit/remove device operations.

### Task 2.4 - Improve connection resilience
- [ ] Add reconnect backoff strategy for temporary network failures.
- [ ] Surface clear UI states: connecting, connected, disconnected, retrying.

## Milestone 3 - UX Polish and Product Readiness

### Task 3.1 - Refine remote UI for fast usage
- [ ] Improve button sizing and thumb reach.
- [ ] Optimize layout for one-hand interaction.
- [ ] Ensure dark mode is consistent and legible.

### Task 3.2 - Add interaction polish
- [ ] Add animations for key interactions.
- [ ] Add haptic feedback per command category where appropriate.
- [ ] Keep perceived latency low with responsive button states.

### Task 3.3 - Improve onboarding and fallback guidance
- [ ] Add clear permission and network guidance.
- [ ] Add "cannot find TV" troubleshooting path.
- [ ] Add protocol-specific help text for pairing issues.

## Cross-Cutting Tasks (Do in parallel)

### Task C1 - Telemetry and diagnostics
- [ ] Track discovery success/failure rates.
- [ ] Track pairing and command error categories.
- [ ] Add internal debug view/log export for troubleshooting.

### Task C2 - Testing strategy
- [ ] Unit tests for domain and command routing.
- [ ] Widget tests for onboarding/pairing/remote states.
- [ ] Integration tests for connect/send command/reconnect paths.

### Task C3 - Platform considerations
- [ ] Android:
  - [ ] LAN discovery: multicast lock + manifest multicast-related permissions for dependable SSDP (Task 1.1)
  - [ ] optional IR behind feature flag
- [ ] iOS:
  - [ ] Wi‑Fi / local network permissions and entitlements per Apple requirements
  - [ ] **Compatible** with `product_specs.md` §1; **release** timing may differ from Android

### Task C4 - Backlog candidates (Post-MVP)
- [ ] IR mode and brand signal testing flow.
- [ ] Voice control integration.
- [ ] Automation routines (watch mode, schedule).
- [ ] Cloud remote access and account sync.
- [ ] Widgets/lockscreen/wearable support.
- [ ] Broader brand expansion beyond Samsung/LG/Hisense.

## Suggested Execution Order (Now)

- [ ] Task 0.1 -> 0.3 (foundation and contracts)
- [ ] Task 1.1 -> 1.5 (vertical slice implementation)
- [ ] Task 1.6 (end-to-end validation)
- [ ] Task 2.1 -> 2.4 (second brand + resilience)
- [ ] Task 3.1 -> 3.3 (polish and usability hardening)

## Definition of Done (Current)

- [ ] User can discover, pair, and control Samsung/LG/Hisense TVs reliably on **Android** (current validation focus).
- [ ] Text input from the app keyboard to Samsung TVs where the WebSocket IME path works on the model.
- [ ] Per-brand text transport/capability flags only after implementation + validation on physical TVs.
- [ ] Relaunch → quick control of last TV; multi-device save/switch; shared command set across brands.
- [ ] Core flows covered by automated tests; CI green.
- [ ] **iOS:** extend the same acceptance criteria when an iOS store release is in scope (parity with §1).

## Final Release Gate (Legal & Compliance)

- [ ] Run a legal/license pass for any adopted external protocol references or copied logic before release.
- [ ] Confirm third-party notices/attributions and license text obligations are satisfied in-app/repository.
- [ ] Record final go/no-go license status in `references/third_party_licenses.md`.
- [ ] Block release if any unresolved copyleft or attribution obligations remain.
- [ ] **Store submission blockers** (expanded checklist: `references/compliance-and-release-requirements.md`):
  - [ ] Privacy policy at a live public URL; linked in App Store Connect and Play Console.
  - [ ] iOS: App Tracking Transparency integrated; prompt before first ad load.
  - [ ] EU/California: consent (for example UMP via `google_mobile_ads`) before ads where required.
  - [ ] Pro / remove-ads: **non-consumable** IAP via Apple IAP + Google Play Billing only (`in_app_purchase`).
  - [ ] Developer accounts and signing: Apple Developer Program, Google Play developer account, AdMob as needed before ads go live.
- [ ] **Physical-device validation:** Do not claim store support for a brand until pairing and core commands are verified on at least one real TV of that brand (complements the brand readiness matrix in `references/product_specs.md`).
- [ ] **Deferred code-quality/security follow-ups** from the April 2026 lib review (no code until individually confirmed): `references/goal-oneremote-lib-review.md`.

## Change Control Notes

- This is a living implementation plan, not a fixed contract.
- Any major scope change should update:
  - milestone priority
  - acceptance expectations
  - test coverage targets
- Prefer incremental delivery with working slices over broad unfinished features.
