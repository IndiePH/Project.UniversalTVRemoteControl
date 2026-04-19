# Goal: OneRemote lib review — deferred improvement tasks

**Product naming:** `references/product_specs.md`.

ID: oneremote-lib-review
STATUS: deferred
CREATED: 2026-04-19

## Objective
Address all findings from the April 2026 security and code-quality review of the OneRemote `lib`
directory. No task is acknowledged — each requires human confirmation and/or brainstorm at execution
time before any code is changed.

## Decisions
- Tasks 2 and 3 are sequenced: Task 3 depends on Task 2's outcome (layout editor extraction may
  reshape the item-id conditional chains).
- All other tasks are independent and may be tackled in any order.
- "Deferred" = tracking only. No implementation until each task is individually confirmed.
- Task 6 revised 2026-04-19: original framing assumed LgAdapter and HisenseAdapter should be
  consistent. Incorrect — LG (webOS/ThinQ) and Hisense (VIDAA/Android TV) use structurally different
  protocols; different sendText stubs may be intentional. Task reframed as a design clarification.

---

## Sub-goal 1 — Security

### Task 1 — Fix TLS certificate bypass in RealSamsungTransportClient [ ]
File: `lib/src/features/remote_control/data/adapters/samsung/real_samsung_transport_client.dart:246–251`
Problem: `badCertificateCallback` returns `true` unconditionally — all TLS certificates accepted
without verification, leaving the app vulnerable to MITM attacks on the local network.
Risk: HIGH (security-sensitive)
Deps: none
Approach unconfirmed — options include cert pinning on first connect, user-acknowledged
trust-on-first-use (TOFU), or a per-host fingerprint store. **Requires brainstorm before
implementation.**

---

## Sub-goal 2 — Architecture / SRP

### Task 2 — Extract layout editor out of RemoteHomePage [ ]
File: `lib/src/features/remote_control/presentation/pages/remote_home_page.dart` (~993 lines)
Problem: Layout editor drag/drop logic, grid math, and layout persistence (~300 lines) live inside
`_RemoteHomePageState`. SRP violation — two distinct UI features in one class.
Risk: MEDIUM (state-modifying, recoverable)
Deps: none
Target widget name and internal state boundary unconfirmed. **Requires brainstorm before
implementation.**

### Task 3 — Refactor item-id conditional chains (_buildRemoteLayoutItem / _actionForItem) [ ]
File: `lib/src/features/remote_control/presentation/pages/remote_home_page.dart:717–917`
Problem: Every new button type requires editing two parallel `if (item.id == '...')` chains. Growing
conditional smell; violates OCP.
Risk: MEDIUM
Deps: Task 2 (extraction may reshape or relocate these methods — tackle after Task 2 settles)
Builder map vs. strategy pattern unconfirmed. **Requires brainstorm; tackle after Task 2.**

---

## Sub-goal 3 — DRY & Consistency

### Task 4 — Deduplicate _capabilitiesForBrand [ ]
Files: `lib/src/features/remote_control/presentation/pages/pairing_page.dart:337`,
       `lib/src/features/remote_control/data/ssdp_device_discovery_service.dart:139`
Problem: Identical brand→capability mapping defined in two separate files. Silent divergence risk
if one is updated without the other.
Risk: LOW
Deps: none
Correct home (extension on `TvBrand`, shared constant, or helper class) unconfirmed. **Requires
confirmation before implementation.**

### Task 5 — Deduplicate _twoDigits [ ]
Files: `lib/src/features/remote_control/presentation/pages/remote_home_page.dart:258`,
       `lib/src/features/remote_control/presentation/pages/pairing_page.dart:540`
Problem: Identical date-formatting one-liner duplicated across two files.
Risk: LOW
Deps: none
Target location unconfirmed — likely alongside Task 4's shared helper. **Requires confirmation.**

### Task 6 — Clarify intended sendText behaviour for LgAdapter and HisenseAdapter [ ]
Files: `lib/src/features/remote_control/data/adapters/lg_adapter.dart:41–48`,
       `lib/src/features/remote_control/data/adapters/hisense_adapter.dart:40–48`
Problem: Both adapters declare `supportsTextInput = false`, but their defensive sendText
implementations differ — LgAdapter throws UnsupportedError; HisenseAdapter logs silently and
returns. This may be intentional: LG (webOS/ThinQ) and Hisense (VIDAA/Android TV) use structurally
different protocols, and the Hisense silent stub could reflect a future implementation path.
Risk: LOW
Deps: none
This is a design clarification task, not a straightforward fix. **Requires confirmation of intent
before any change is made.** If the difference is intentional, the task closes with a code comment
documenting why. If not, the correct defensive behaviour needs agreement.

### Task 7 — Remove reimplemented firstOrNull extension [ ]
File: `lib/src/features/remote_control/presentation/pages/remote_home_page.dart:990–992`
Problem: `firstOrNull` getter reimplemented locally; available natively on `List` in Dart 3 or via
`package:collection`.
Risk: LOW
Deps: none
Whether to rely on the Dart 3 built-in or add `package:collection` needs confirmation.

---

## Sub-goal 4 — Code Structure

### Task 8 — Centralize magic color constants [ ]
Files: `lib/src/features/remote_control/presentation/pages/remote_home_page.dart`,
       `lib/src/features/remote_control/presentation/widgets/remote_circular_dpad.dart`,
       `lib/src/features/remote_control/presentation/widgets/remote_vertical_rocker.dart`,
       `lib/src/features/remote_control/presentation/widgets/remote_icon_circle_button.dart`
Problem: `Color(0xFF1B1D22)`, `Color(0xFF111317)`, `Color(0xFF2D3138)` hard-coded across four
widget files with no shared name. Silent inconsistency risk on theme changes.
Risk: LOW
Deps: none
Whether to extend `AppTheme`, create an `AppColors` constant class, or map to Material color roles
unconfirmed. **Requires confirmation.**

### Task 9 — Move LayoutPosition to domain/models [ ]
File: `lib/src/features/remote_control/application/layout_repository.dart:1–26`
Problem: `LayoutPosition` is a domain-level coordinate concept defined inside the application-layer
repository file. Violates layer boundaries.
Risk: LOW
Deps: none
Target path: `lib/src/features/remote_control/domain/models/layout_position.dart`.
**Requires confirmation before move.**
