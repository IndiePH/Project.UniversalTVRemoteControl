# RemoteOne Implementation Tasks (Living Plan)

This task list is derived from `references/product_specs.md` and is intended to be iterative.  
As product specs evolve, update this document and re-prioritize tasks.

## Status Tracker (Current)

### Completed
- Milestone 0 / Task 0.1:
  - Established layered structure (`presentation` / `application` / `data` / `domain`)
  - Added extensible brand adapter contracts and router-based dispatch
- Milestone 0 / Task 0.3:
  - Added core entities and contracts:
    - `TvDevice`, `TvBrand`, `RemoteCommand`, `DeviceCapability`, `ConnectionState`
    - command dispatch result model and service interfaces
- Milestone 1 / Task 1.3 (partial):
  - Implemented remote surface with custom controls:
    - power, mute, d-pad + OK, channel rocker, volume rocker
    - text input field + send action
  - Added responsive sizing fixes for control cluster
- Milestone 1 / Task 1.4 (partial):
  - Implemented command pipeline with brand-specific routing
  - Added adapter capability checks (`supportedCommands`, `supportsTextInput`)
  - Added non-throwing dispatch results for UI-safe error handling
- Milestone 1 / Task 1.2 (partial):
  - Added pairing screen with:
    - scan flow wired to local-network SSDP discovery
    - manual brand + IP add
    - IPv4 validation
    - recent manual IP shortcuts
    - saved device quick-reconnect section
    - remove saved device flow (with active-device extra confirmation)
    - explicit pairing behavior notice (new successful pair switches active TV; prior saved devices remain until removed)
- Milestone 1 / Task 1.5 (partial):
  - Persist/select last used device
  - Track and surface `lastSuccessfulPairingAt` metadata
  - Removed seeded in-memory placeholder saved device (app now starts with no paired TV by default)
- Milestone 3 / Task 3.1 (partial):
  - Added settings-driven grid layout editor with drag/drop + swap behavior
  - Added layout persistence and default-layout reset flow
  - Fixed multi-cell drag anchor behavior for d-pad (grab-point independent)
  - Added search-input composite layout item and updated it to `5x1` (`4x1` text + right icon action)
  - Restored channel/volume rocker controls and aligned play/pause visual as compact `1x1` control (left play icon + right pause icon)
  - Added directional visual padding tuning for d-pad arrows (up/down/left/right)
  - Increased editable/control grid from `5x8` to `5x9`
  - Updated default control coordinates for the latest baseline layout

### In Progress
- Milestone 1 / Task 1.6:
  - Basic widget test coverage is in place
  - Added full-loop widget pass:
    - pair to newly discovered TV
    - return to remote
    - send command via remote control
  - Added active-device remove confirmation regression coverage (`REMOVE` path)
  - Broader scenario tests and network edge-case validation pending
- Milestone 3 / Task 3.1:
  - Continue usability polish for edit mode visual affordances and small-screen readability

### Next Up
- Connect pairing output to real protocol handshake/verification per brand
- Expand tests:
  - pairing success/failure paths
  - adapter capability unsupported flows
  - saved-device remove/last-used fallback paths
- Add focused widget tests for:
  - drag/drop swap behavior (including multi-cell items)
  - layout persistence and default reset behavior
  - `5x9` default layout occupancy constraints (no overlaps)

## Planning Notes

- Current source of truth: `references/product_specs.md`
- Delivery principle: speed to market over perfection
- Initial implementation focus:
  - Flutter app architecture
  - Android-first support
  - Wi-Fi control first
  - Samsung/LG/Hisense-first compatibility based on available hardware
  - iOS-safe architecture for Post-MVP rollout
- Scope can change as we learn from implementation and testing.

## Milestone 0 - Project Foundation

### Task 0.1 - Establish architecture and module boundaries
- Define app layers: presentation, domain, data, device communication.
- Create contracts for remote commands and device sessions.
- Decide state management approach and dependency wiring pattern.
- Document extension points for adding new TV protocols.

### Task 0.2 - Setup environment and quality baseline
- Confirm Flutter project settings and lint/test configuration.
- Add CI checks for format, analyze, and tests.
- Add app flavor/config placeholders for debug and release.

### Task 0.3 - Define shared domain models
- Create core entities:
  - TV device
  - Device capability
  - Remote command
  - Connection state
  - Saved device profile
- Define serialization contracts for local persistence.

## Milestone 1 - Vertical Slice (Samsung + LG first)

### Task 1.1 - Implement Samsung/LG discovery
- Build local network discovery flow for Samsung and LG targets.
- Show discovery results with loading, empty, and error states.
- Add retry behavior and timeout handling.

### Task 1.2 - Implement manual pairing flow
- Build device selection and pairing screen flow.
- Validate and persist successful pairing credentials.
- Add user-facing error states for failed pairing attempts.

### Task 1.3 - Build minimal remote control surface
- Implement controls:
  - Power
  - Volume up/down
  - D-pad + OK
  - Back/Home
  - Text input keyboard for search/forms
- Wire controls to Android TV command adapter.
- Wire controls to Samsung/LG command adapters.
- Provide immediate press feedback (visual + optional haptic hook).

### Task 1.4 - Build command execution pipeline
- Create unified `sendCommand(deviceId, command)` service.
- Add command result mapping (success, timeout, unavailable).
- Add support for text input command payloads for compatible protocols.
- Add lightweight logging hooks for command failures.

### Task 1.5 - Persist and restore one saved device
- Save paired device locally.
- Auto-reconnect to last used device on app relaunch.
- Handle stale/invalid session recovery paths.

### Task 1.6 - Validate end-to-end vertical slice
- Verify first-time flow:
  - discover -> pair -> remote control -> save device
- Verify returning flow:
  - app launch -> auto-connect -> immediate remote use
- Add integration/widget tests for critical paths.

## Milestone 2 - Expansion (Hisense + multi-device)

### Task 2.1 - Add/validate Hisense protocol adapter
- Implement Hisense TV connection and command transport (best-effort).
- Map shared command set to Hisense-specific commands where supported.
- Add protocol-specific error handling and reconnection behavior.

### Task 2.2 - Upgrade discovery and device type identification
- Distinguish supported device brands in discovery results.
- Route pairing flow to the correct protocol adapter.
- Add explicit "limited support" messaging for partially supported models/protocols.

### Task 2.3 - Implement multi-device management
- Save multiple TVs.
- Add device switcher and last-used device tracking.
- Add edit/remove device operations.

### Task 2.4 - Improve connection resilience
- Add reconnect backoff strategy for temporary network failures.
- Surface clear UI states: connecting, connected, disconnected, retrying.

## Milestone 3 - UX Polish and Product Readiness

### Task 3.1 - Refine remote UI for fast usage
- Improve button sizing and thumb reach.
- Optimize layout for one-hand interaction.
- Ensure dark mode is consistent and legible.

### Task 3.2 - Add interaction polish
- Add animations for key interactions.
- Add haptic feedback per command category where appropriate.
- Keep perceived latency low with responsive button states.

### Task 3.3 - Improve onboarding and fallback guidance
- Add clear permission and network guidance.
- Add "cannot find TV" troubleshooting path.
- Add protocol-specific help text for pairing issues.

## Cross-Cutting Tasks (Do in parallel)

### Task C1 - Telemetry and diagnostics
- Track discovery success/failure rates.
- Track pairing and command error categories.
- Add internal debug view/log export for troubleshooting.

### Task C2 - Testing strategy
- Unit tests for domain and command routing.
- Widget tests for onboarding/pairing/remote states.
- Integration tests for connect/send command/reconnect paths.

### Task C3 - Platform considerations
- Android:
  - prioritize all MVP features
  - prep optional IR capability behind feature flag
- iOS:
  - design Wi-Fi/local network permission handling during Android development
  - keep iOS implementation behind staged rollout gates

### Task C4 - Backlog candidates (Post-MVP)
- IR mode and brand signal testing flow.
- Voice control integration.
- Automation routines (watch mode, schedule).
- Cloud remote access and account sync.
- Widgets/lockscreen/wearable support.
- Broader brand expansion beyond Samsung/LG/Hisense.

## Suggested Execution Order (Now)

1. Task 0.1 -> 0.3 (foundation and contracts)
2. Task 1.1 -> 1.5 (vertical slice implementation)
3. Task 1.6 (end-to-end validation)
4. Task 2.1 -> 2.4 (second brand + resilience)
5. Task 3.1 -> 3.3 (polish and usability hardening)

## Definition of Done (Current)

- Android user can discover, pair, and control Samsung/LG TVs reliably.
- Android user can send text input to compatible TVs for search/forms.
- User can relaunch app and control last connected TV quickly.
- Samsung and LG support work with shared remote command set.
- Hisense support is delivered when protocol validation succeeds on physical devices.
- Multiple TVs can be saved and switched.
- Core flows are covered by automated tests and pass CI checks.

## Change Control Notes

- This is a living implementation plan, not a fixed contract.
- Any major scope change should update:
  - milestone priority
  - acceptance expectations
  - test coverage targets
- Prefer incremental delivery with working slices over broad unfinished features.
