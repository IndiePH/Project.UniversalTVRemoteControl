# Goal: OneRemote `lib` review — improvement tasks (complete)

**Product naming:** `references/product_specs.md`.

| Field | Value |
| --- | --- |
| ID | oneremote-lib-review |
| STATUS | **complete** |
| CREATED | 2026-04-19 |
| COMPLETED | 2026-04-19 |

## Objective (archived)

Address findings from the April 2026 security and code-quality review of the OneRemote **`lib/`**
directory. All tracked tasks (1–9) were implemented; see sections below for file references and notes.

**Scope:** Primary changes live under **`lib/`**. Supporting updates (e.g. **`test/`** imports,
this tracker) were applied where imports or verification required it.

## Decisions (historical)

- Tasks 2 and 3 were sequenced: Task 3 depended on Task 2 (layout editor extraction could reshape
  item-id conditional chains).
- Other tasks were independent.
- Original process: tasks were confirmed before implementation; this document tracked scope and outcomes.
- Task 6 (2026-04-19): reframed — LG (webOS/ThinQ) and Hisense (VIDAA/Android TV) differ by protocol;
  divergent `sendText` stubs may be intentional; see Task 6 notes.

---

## Sub-goal 1 — Security

### Task 1 — Fix TLS certificate bypass in RealSamsungTransportClient [x]

**File:** `lib/src/features/remote_control/data/adapters/samsung/real_samsung_transport_client.dart` (`_openSocket`)

**Implemented 2026-04-19:** Trust-on-first-use (TOFU) with per-`host:port` SHA-256 pin persisted via
`SharedPreferences` (`samsung_tls_trust_store.dart`). First connect pins the cert; later connects must
match or handshake fails (MITM / TV cert change). Clear app data resets pins.

**Follow-up 2026-04-20 (SRP):** Pairing/token waiters, IME session state, debug logging, and WSS handshake
completion were extracted from `real_samsung_transport_client.dart` into focused types under the same
`samsung/` adapter folder; the client keeps socket lifecycle and outbound framing.

- **Risk:** HIGH (security-sensitive) — mitigated vs unconditional accept; TOFU still trusts first sighting.
- **Deps:** `crypto` (see `references/third_party_licenses.md`)

---

## Sub-goal 2 — Architecture / SRP

### Task 2 — Extract layout editor out of RemoteHomePage [x]

**Files:**

- `lib/src/features/remote_control/presentation/pages/remote_home_page.dart`
- `lib/src/features/remote_control/presentation/widgets/remote_layout_editor.dart`

**Implemented 2026-04-19:** Drag/drop grid editor UI and edit-mode interaction state were extracted to
`RemoteLayoutEditor` with shared `LayoutEditItem`. `RemoteHomePage` delegates editor rendering and keeps
page-level orchestration (device, commands, layout load/save) focused.

**Follow-up 2026-04-20:** Grid drop/swap resolution moved to `RemoteLayoutDropResolver` (`remote_layout_drop_resolver.dart`) so placement rules stay testable and the editor stays presentation-focused; swap uses footprint-aware displaced placement with direction-prioritized edge candidates.

- **Risk:** MEDIUM (state-modifying, recoverable) — behavior preserved via callbacks (`onResetLayout`, `onPersistLayout`).
- **Deps:** none

### Task 3 — Refactor item-id conditional chains (`_buildRemoteLayoutItem` / `_actionForItem`) [x]

**File:** `lib/src/features/remote_control/presentation/pages/remote_home_page.dart`

**Implemented 2026-04-19:** Replaced long `if (item.id == '...')` / switch chains with centralized registries:

- `_customBuilderByItemId` — specialized widgets (dpad, search, playPause, channel, volume, pair)
- `_commandByItemId` — standard icon-button command routing
- `_customActionByItemId` — non-command actions (`pair`)

Fallback remains explicit (`_noopAction`).

**Follow-up 2026-04-20 (SRP continuation):** `RemoteHomePage` kept the map-based routing from Task 3 and
further moved presentational sections into focused widgets:
`RemoteTextEntrySheet`, `RemoteHomeStatusPanel`, `RemoteHomeAppBarActions`, `RemoteHomeDebugSheet`,
`RemoteHomeRemoteGrid`, and `RemoteHomeActions`.
Keyboard availability checks were centralized in `RemoteKeyboardAvailability`.
Page-level orchestration remains in `_RemoteHomePageState` and is tracked in
`references/implementation_tasks.md` (SRP checklist).

**Follow-up 2026-04-20 (layout editor SRP):** `RemoteLayoutEditor` was split so geometry, grid
painting, per-item previews, and drag-session state live in dedicated types next to
`RemoteLayoutDropResolver`; the editor widget retains gesture targets and layout chrome.

**Follow-up 2026-04-20 (pairing SRP):** `PairingPage` orchestration and UI sections were split into
`PairingPageCoordinator`, `PairingPageData`, `PairingPageDialogs`, `PairingPageViewState`, and
`lib/.../widgets/pairing_page_sections.dart`; see the same SRP checklist in `implementation_tasks.md`.

- **Risk:** MEDIUM
- **Deps:** Task 2 complete

---

## Sub-goal 3 — DRY & consistency

### Task 4 — Deduplicate `_capabilitiesForBrand` [x]

**Files:**

- `lib/src/features/remote_control/domain/models/tv_brand_capabilities.dart`
- `lib/src/features/remote_control/presentation/pages/pairing_page.dart`
- `lib/src/features/remote_control/data/ssdp_device_discovery_service.dart`

**Implemented 2026-04-19:** Capability defaults moved to `TvBrandCapabilities` (`TvBrand.defaultCapabilities`).
Pairing and SSDP discovery consume the same source.

- **Risk:** LOW
- **Deps:** none

### Task 5 — Deduplicate `_twoDigits` [x]

**Files:** `remote_home_page.dart`, `pairing_page.dart` (shared timestamp formatting paths)

**Problem:** Duplicate date-formatting helper across two files.

**Implemented 2026-04-19:** Shared `formatTwoDigits` in
`lib/src/features/remote_control/presentation/formatting/two_digit_format.dart`.

- **Risk:** LOW
- **Deps:** none

### Task 6 — Clarify intended `sendText` behaviour for LgAdapter and HisenseAdapter [x]

**Files:** `lg_adapter.dart`, `hisense_adapter.dart` (`sendText`)

**Closed (option A — intentional):** Different protocol surfaces; each adapter documents `sendText` in `///`.
Both keep `supportsTextInput == false` until a real path exists and use `UnsupportedError` so the UI does not assume delivery.

**Validation note:** Testing has focused on **Samsung**. **LG** may change when real transport work starts.
**Hisense** may change with protocol/hardware findings (see `references/product_specs.md`).

- **Risk:** LOW
- **Deps:** none

### Task 7 — Remove reimplemented `firstOrNull` extension [x]

**File:** `lib/src/features/remote_control/presentation/widgets/remote_layout_editor.dart`

**Implemented 2026-04-19:** Removed local `extension on Iterable`; `import 'dart:collection';` provides
`Iterable.firstOrNull`.

- **Risk:** LOW
- **Deps:** none

---

## Sub-goal 4 — Code structure

### Task 8 — Centralize magic color constants [x]

**Files:** `remote_home_page.dart`, `remote_circular_dpad.dart`, `remote_vertical_rocker.dart`,
`remote_icon_circle_button.dart`

**Implemented 2026-04-19:** `AppColors` theme extension in `lib/src/theme/app_theme.dart` with
`AppTheme.createAppColors` / `AppTheme.colorsOf(context)`. Semantic tokens: `remoteSurface`,
`remoteRaisedSurface`, `remoteOutline`.

- **Risk:** LOW
- **Deps:** none

### Task 9 — Move `LayoutPosition` to `domain/models` [x]

**Problem:** `LayoutPosition` lived in `layout_repository.dart` though it is a domain coordinate type.

**Implemented 2026-04-19:** `lib/src/features/remote_control/domain/models/layout_position.dart`; repository,
data, presentation, and tests updated to import the domain model. Related decoupling: application port
`TransportLogReader` + data adapter for Samsung transport log sharing (see `transport_log_reader.dart`,
`samsung_transport_log_reader.dart`).

- **Risk:** LOW
- **Deps:** none
