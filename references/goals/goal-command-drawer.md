# Goal: Command Drawer (excluded-but-valid commands)

**Branch:** `feature/command-drawer` (current)
**Status:** proposed — analysis only, **NOT FINALIZED**
**Related:** `references/goals/goal-variant-remote-layout.md` (same underlying data model — likely built together); `references/goals/goal-stable-device-identifier.md` (this goal's persisted state inherits that goal's `deviceId` fragility, not a blocker)
**Analysis session:** `references/goals/goal-command-drawer-and-variant-layouts.md`

> ⚠️ **This document has not been verified or approved by the user.** Every claim under
> "Verified facts" was confirmed by direct source reads (file:line cited) as of 2026-08-20,
> but the user has explicitly not yet checked this against their own understanding. Do not
> treat this as a spec. Everything under "Proposed design" is a recommendation only.

---

## Problem statement

The user wants a "command drawer": a place to put a command that is valid for a paired
device (the adapter supports it) but that they don't want shown in the main remote button
layout — retrievable/re-addable later, rather than permanently absent.

## Verified facts (direct source reads, 2026-08-20)

1. ~~**No drawer-equivalent exists today.** `LayoutPosition` (`lib/remote_control/domain/models/layout_position.dart:2-21`) holds only `col`/`row` — no visible/hidden/enabled field of any kind.~~ **Superseded by Phase 1 (2026-08-21): `LayoutPosition` (`layout_position.dart:4-35`) now also holds `zone: LayoutZone` (`grid`/`drawer`)** — this is the drawer-equivalent field this fact originally found missing.
2. ~~**`LayoutEditItem`** (`lib/remote_control/presentation/widgets/layout_edit_item.dart:4-26`) — the mutable runtime item — also has no enabled/disabled/hidden field. Checked in full; confirmed absent.~~ **Superseded by Phase 1 (2026-08-21): `LayoutEditItem` (`layout_edit_item.dart:5-28`) now has a mutable `zone: LayoutZone` field**, mirroring `LayoutPosition`.
3. ~~**Layout catalog is fixed and global.** `kRemoteLayoutItemDefinitions` (`lib/remote_control/presentation/widgets/remote_layout_item_definitions.dart:67-156`) is a hardcoded list of 14 item ids (power, menu, volume, playPause, www, dpad, channel, home, back, mute, netflix, disney, prime, searchInput) with fixed grid geometry — same for every brand.~~ **Superseded by Phase 2 (2026-08-21): the catalog now has 16 items** (`remote_layout_item_definitions.dart:92-228`) — the original 14 plus `youtube` and `input`. Still fixed/global (same list for every brand) — only the count changed.
4. **Filtering is capability-only, not user choice.** `buildFilteredRemoteLayoutItems` (`remote_layout_item_definitions.dart:251-276`) includes an item only if `supportedCommands.containsAll(definition.commands)` (or `supportsTextInput` for `searchInput`). An unsupported command's item is **fully omitted** — never rendered anywhere, not even as disabled. (Still true post-Phase-2; this is exactly what Phase 3 changes.)
5. ~~**Proof of the gap:** `RemoteCommand.youtube` and `RemoteCommand.input` (`lib/remote_control/domain/models/remote_command.dart:9,14`) are valid, dispatchable commands — `youtube` is in `kCommonSupportedRemoteCommands` (`supported_remote_commands.dart:17`) and wired into every adapter's key mapper — but **neither has a case in `requiredCommandsForLayoutItemId` or `commandForLayoutItemId`** (`remote_layout_item_definitions.dart:170-209`). They are unreachable from any UI today — not hidden, just absent.~~ **Fixed by Phase 2 (2026-08-21):** both now have catalog entries (`youtube` at `remote_layout_item_definitions.dart:212-218`, `input` at `:221-227`) with `commands: {RemoteCommand.youtube}` / `{RemoteCommand.input}`. They render on the main grid today for any device whose adapter supports them — see the Phase 3 caveat below for why that's still not the intended end state.
6. **"Command exists for this device" = "command is in the resolved adapter's `supportedCommands` set."** `BrandRoutedRemoteCommandService._adapterFor(brand, variant)` (`lib/remote_control/data/brand_routed_remote_command_service.dart:278-279`) does a `Map<(TvBrand, String), TvBrandAdapter>` lookup; `supportedCommandsFor(device)` delegates straight to that adapter's `supportedCommands` getter. This is already the source of truth the drawer would key off of — no new "does this command exist" logic is needed, only a new "is it currently excluded from the layout by user choice" state.
7. **Per-adapter command sets differ** (confirmed by direct read of each adapter file):
   - `android_tv`, `tcl_google_tv` (`TvBrand.tcl`, variant `googleTv`), `samsung`, `hisense`, `lg` all use the shared `kCommonSupportedRemoteCommands` (21/21 `RemoteCommand` values — i.e. this set is currently the *entire* enum, not a curated subset).
   - `TclRokuAdapter` (**`TvBrand.roku`**, its own top-level brand — not a TCL variant, despite the filename `tcl_roku_adapter.dart`) defines its own 20-command set, excluding `RemoteCommand.web` (`tcl_roku_adapter.dart:25-46,49`).
   - `TclLegacyWifiAdapter` (`TvBrand.tcl`, variant `legacyWifi`) defines a further-restricted 16-command set with **zero app-shortcut commands** (`tcl_legacy_wifi_adapter.dart:19-36`).

## Proposed design (undecided — for discussion)

1. ~~Extend the persisted layout state to separate positioned/visible items from a known-but-drawer-parked set~~ — **resolved, see Decisions: `LayoutPosition.zone` (`LayoutZone.grid`/`LayoutZone.drawer`) field chosen.**
2. ~~Extend `kRemoteLayoutItemDefinitions`/`requiredCommandsForLayoutItemId`/`commandForLayoutItemId` to cover every `RemoteCommand` that any adapter's `supportedCommands` set can produce (per `TvCapabilities`/adapter `supportedCommands`, verified fact #6) — uniformly, not a special case for `youtube`/`input`. Verified fact #5 (`youtube`/`input` currently unreachable) is one instance of this gap, not the whole of it; the fix should cover every command the layout catalog is currently missing so any capability-supported command can have a drawer representation.~~ — **resolved by Phase 2 (2026-08-21): see Decisions for the `commands`/`dispatchCommand` field design that replaced the two switch statements, and Verified fact #5 above for the `youtube`/`input` closure.**
3. ~~A UI surface (drawer strip within the editor) listing capability-supported-but-not-placed items, with add/remove actions~~ — **resolved, see "Proposed UX design — drawer interaction" below: a fixed, always-visible drawer strip, drag-based add/remove in both directions.** (`remote_layout_editor.dart` currently only supports drag-repositioning of items already present — no picker exists yet; grepped for `remove|delete|hide|drawer|overflow|toggle`, no relevant hits — confirms this is genuinely new UI, not an extension of an existing picker.)
4. Small, non-breaking `SharedPreferences` shape addition — `LayoutPosition` gains `zone` (an enum, default `LayoutZone.grid` when absent), per Decisions below. No migration script needed; existing persisted data reads correctly under the new default.

## Decisions

- **Terminology:** "positioned" = an item with `zone: LayoutZone.grid` (or absent, defaulting to `LayoutZone.grid`) in `LayoutRepository`'s `Map<String, LayoutPosition>` (`layout_repository.dart:4`) — i.e. currently placed/visible on the grid at its `col`/`row`. "Drawer" = adapter-`supportedCommands` items that are either absent from that map, or present with `zone: LayoutZone.drawer`.
- 2026-08-20 (**revised** — see next bullet): ~~Design option (b), fully derived, no persisted field~~ superseded. Pure derivation (absence = drawer) has a real edge case: if a Pro user drags *every* item out of the grid, the saved-positions map goes empty, and the app currently infers "empty map = never customized" (`_loadLayoutForDevice`, verified fact #9 in `goal-variant-remote-layout.md`) — so on next load it would silently repopulate the full default set, undoing the user's explicit choice.
- 2026-08-20 (**superseded by next bullet**): ~~drawer state persists via a sentinel `col: -1, row: -1` position~~ — replaced with a proper field, see below.
- 2026-08-21 (**revised same day**): ~~`LayoutPosition` gains a new `bool inDrawer` field~~ superseded — **`LayoutPosition` gains an `enum LayoutZone { grid, drawer }` field named `zone` instead of a bare `bool`.** Same underlying schema change (one new field, non-breaking, defaults correctly for already-persisted data — absent `zone` reads as `LayoutZone.grid`, matching the fact that nothing shipped has ever been drawer-parked), but per user feedback an enum reads clearer at call sites (`position.zone == LayoutZone.drawer` vs. a bare `true`/`false`) and leaves room for a future third zone without another boolean bolted on later. A drawer-parked command sets `zone: LayoutZone.drawer` and **keeps its last real `col`/`row`** instead of losing it — preserved in case a future "restore to last spot" convenience is wanted, per user: "persist the original row,col if we ever want to use it." Restoring sets `zone: LayoutZone.grid`; whether the drop then reuses the preserved position as a suggestion or the user just drags to a fresh cell is a smaller UI decision, not blocked by this data choice either way. This also still resolves the magic-number tradeoff flagged against the earlier sentinel-position approach — no reserved out-of-bounds value to remember, and now no bare boolean either.
- 2026-08-21: **Field renamed `category`/`LayoutCategory` → `zone`/`LayoutZone` (same enum, same `grid`/`drawer` values, name only).** Per user feedback: "category" doesn't read as grid-vs-drawer at a glance, whereas "zone" evokes the spatial region an item lives in, matching how `col`/`row` already describe physical placement. Applied everywhere the field existed: `LayoutPosition`/`LayoutEditItem`'s field, the enum's own file (`layout_category.dart` → `layout_zone.dart`), the persisted JSON key (`'category'` → `'zone'`, safe to change since nothing has shipped with saved layout data yet), and `resolveDefaultLayoutItemCategory` → `resolveDefaultLayoutItemZone`. Done immediately after Phase 3 landed, before Phase 4 added more call sites depending on the old name. Verified via `flutter analyze` (clean) and `flutter test` (402 passed).
- 2026-08-20: **Default drawer-vs-positioned state for any command (including `youtube`/`input`) matches that `(brand, variant)`'s default set**, per the `RemoteLayoutDefaults` map defined in `goal-variant-remote-layout.md` (see that doc for what determines the default set — no longer strictly physical-remote-bound, see its latest revision). A command starts positioned if it's in that variant's default set; starts in the drawer if the adapter supports it but the default set doesn't include it. This makes the drawer's default state a direct consequence of variant-layout's data, not an independent decision here.
- 2026-08-20: **Pro-gating, confirmed:** editing/repositioning — including drawer drag-in/drag-out, since that's a position edit — is **Pro-only**, matching the existing layout-editor gate (`remote_home_page.dart:1084-1087`). The *default* command set itself (which commands a free user sees, per their device's brand+variant) is **not** Pro-gated — showing the correct commands for a device is a correctness matter, not a customization perk, and matches how defaults already work for everyone today.
- 2026-08-21: **`RemoteLayoutItemDefinition`'s OCP fields are named `commands: Set<RemoteCommand>` and a derived getter `dispatchCommand`, not the originally-planned `requiredCommands`/`command`.** Per user feedback during Phase 2 (`RemoteLayoutItemDefinition` was hard to read with two similarly-named-but-differently-purposed fields): `commands` holds every `RemoteCommand` the device must support for the item to appear at all (empty means "not gated by a command" — today only `searchInput`, gated by `supportsTextInput` instead). `dispatchCommand` is **not a stored field** — it's `commands.length == 1 ? commands.single : null`, computed on read. Storing it separately was rejected: `dpad`/`volume`/`channel` need multiple `commands` but have no single "the tap action" (their sub-controls dispatch individually), and a second stored field for the single-command case would reopen the exact split-registry-drift failure mode that originally caused `youtube`/`input` to go missing from one switch statement while present in the other (verified fact #5, pre-fix). Verified against all 16 catalog items with zero counterexamples; documented limitation: a future item needing >1 required command but exactly 1 dispatch command would need a real (non-derived) field — no such item exists today.
- 2026-08-20: **Build this goal first, before `goal-variant-remote-layout.md`, confirmed.** This work already touches every entry in `kRemoteLayoutItemDefinitions` (extending coverage to `youtube`/`input`) and is the natural point to fold `requiredCommandsForLayoutItemId`/`commandForLayoutItemId` into declarative fields on `RemoteLayoutItemDefinition` (OCP cleanup — see design review in `goal-variant-remote-layout.md` finding #4). The variant-layout goal then seeds its per-`(brand,variant)` catalogs from this goal's finished shape, avoiding rework.
- 2026-08-21: **Persist-on-change and reset-to-default already exist for positions and extend naturally** to `zone`-flagged entries — no new save/load pathway, just one more field riding along with the values already flowing through it:
  - `RemoteLayoutEditor.onAcceptWithDetails` already calls `widget.onPersistLayout()` on every accepted drop (`remote_layout_editor.dart:167`) — auto-save per change, no separate save step; a drag-to-drawer persists the same entry with `zone: LayoutZone.drawer` and its `col`/`row` unchanged.
  - The editor header's `restart_alt` icon already wires to `_resetLayoutForActiveDevice()` → `_resetLayoutToDefaults()` → re-persists the cleared state (`remote_home_page.dart:1159-1167`, `1072-1081`); reset replaces the whole map with the default profile's real positions (`zone: LayoutZone.grid` throughout), so no leftover drawer-parked entries survive a reset.

## Proposed UX design — drawer interaction (revised 2026-08-20 per user feedback)

Grounded directly in `remote_layout_editor.dart` and `remote_home_page.dart` (pencil icon = `Icons.edit_outlined` in `remote_home_app_bar_actions.dart:31` → `_toggleLayoutEditMode`, confirmed).

1. **Always visible during edit mode — no toggle icon, no open/close step.** The earlier icon-triggered-overlay proposal added a tap the user has to discover before they can even use the drawer. That protection wasn't actually needed: the "cancel edit" control (the pencil icon, `Icons.edit_outlined`) lives in the app bar (`remote_home_app_bar_actions.dart`), **outside** `RemoteLayoutEditor` entirely — there was never a collision to guard against. Instead, add the drawer as a **fixed, permanently-present region** in `RemoteLayoutEditor.build`'s existing `Column` (`remote_layout_editor.dart:283-318` pre-Phase-5; `build()` is now at `:379-420` post-Phase-5) — e.g. a slim horizontally-scrollable strip between the header and the grid canvas. Because it's never toggled on/off during an edit session, `RemoteLayoutEditorGridGeometry.fitCellSize` computes the grid's available space once, consistently, for the whole session — "not intrusive to positioning" is satisfied by the drawer's presence being constant, not by a show/hide mechanic.
2. **Both remove and restore are drag, not tap.** Tap-to-restore was rejected earlier: the item would place itself automatically somewhere in the grid the user didn't choose, "confusing... you'll need to look for it." Drag keeps the destination visible and user-chosen, consistent with how repositioning already works.
   - **Remove (grid → drawer):** the drawer strip is a `DragTarget<String>` — the user drags a grid item (already `Draggable<String>`, no new widget needed) into it to park it (sets `zone: LayoutZone.drawer`, keeps `col`/`row` as-is, per Decisions above).
   - **Restore (drawer → grid):** drawer items are also `Draggable<String>` (reusing `RemoteLayoutEditorItemPreview` for feedback/preview, same as grid items) — the user drags one out onto a chosen grid cell. Grid cells' existing `DragTarget<String>` (`remote_layout_editor.dart:105-168` pre-Phase-5; `:204-303` post-Phase-5) already validates footprint/occupancy via `RemoteLayoutEditorDragSession`/`RemoteLayoutEditorGridGeometry` — no new validation logic needed, the drop just needs to also accept drags originating from the drawer, not only from other grid cells.
   - One interaction language throughout edit mode — drag between zones — no separate tap-badge gesture to learn.
3. Both directions call `onPersistLayout()` immediately, matching the existing auto-persist-on-change pattern. Empty-state text in the drawer ("Drag a command here to remove it from your remote") for discoverability.
4. Drawer items reuse `RemoteLayoutEditorItemPreview` (already used for grid items and drag feedback) — no new preview widget needed, visual consistency for free.
5. Items with `zone: LayoutZone.drawer` must be filtered out of the grid-canvas render path and routed to the drawer strip's render path instead — the one new bit of rendering logic this design needs.

## Implementation plan (2026-08-21, grounded in direct source reads)

Ordered by dependency (each phase's output is what the next phase consumes). Applies SRP,
OCP, DIP, and architecture-consistency deliberately at each step — called out inline. Phases
1 and 2 have since been implemented (2026-08-21); phases 3-7 are still analysis/plan only.

**Implementation note, added during Phase 2 (2026-08-21): `LayoutItemId` is a `String`-typed
class of named constants, not an enum.** The catalog gap (`youtube`/`input`) surfaced that
layout item ids were scattered as raw string literals in three places (`kRemoteLayoutItemDefinitions`,
a widget-selection `switch` in `remote_home_remote_grid.dart`, and footprint special-casing in
`remote_layout_editor_grid_geometry.dart`). A closed `enum LayoutItemId` was tried first, but
`remote_layout_drop_resolver_test.dart` legitimately depends on being able to construct
synthetic, non-catalog ids (e.g. `fill-$col-$row`, up to ~36 of them) to stress-test the pure
grid-geometry algorithm independent of the real 16-item catalog — a closed enum can't represent
that. Converting only the catalog/persistence layer to an enum while keeping the resolver/drag
layer on `String` was considered and abandoned as too large a propagation (it would have
required `LayoutRepository`/`SharedPrefsLayoutRepository`'s JSON boundary, `Draggable<String>`/
`DragTarget<String>` generics, and several `Map<String, ...>` structures to change shape or gain
a conversion seam, for marginal benefit over the simpler fix). `LayoutItemId` as
`abstract final class` with `static const String` members gets the same typo-safety and
autocomplete benefit at every literal-comparison site, with **zero** changes required to
`LayoutRepository`, `SharedPrefsLayoutRepository`, the resolver, the drag session, or any of
their tests — confirmed by a full `flutter analyze` + test run after the change.

**Phase 0 — Precondition already satisfied.** Four existing test files touch this exact
surface: `test/lib/remote_control/data/shared_prefs_layout_repository_test.dart`,
`remote_layout_grid_constraints_test.dart`, `remote_layout_editor_widget_test.dart`,
`remote_layout_drop_resolver_test.dart`. This answers the open refactoring-precondition
question flagged in `goal-variant-remote-layout.md` finding #3 (for this goal, at least):
there is coverage to refactor against, not a blind rewrite.

**Phase 1 — Domain model (SRP: isolate the new state as its own type, don't overload `col`/`row`).**
- New `enum LayoutZone { grid, drawer }`, own file, matching the one-concept-per-file
  convention already used by `layout_position.dart` / `layout_edit_item.dart`.
- `LayoutPosition` (`layout_position.dart:4-35`): add `final LayoutZone zone`,
  default `LayoutZone.grid`. `toJson` adds `'zone': zone.name`; `fromJson` parses
  defensively and falls back to `LayoutZone.grid` when the key is absent or unrecognized —
  preserves the non-breaking guarantee already recorded in Decisions (old persisted blobs have
  no `zone` key at all).
- `LayoutEditItem` (`layout_edit_item.dart:5-28`): mirror with a **mutable** `zone` field
  (mutable like `col`/`row`, since drag operations flip it live) — this is the type the running
  editor actually reads from (`_layoutItems`, `remote_home_page.dart:92`), so the runtime model
  needs the field independently of the persisted one.
- `RemoteLayoutItemDefinition.toLayoutEditItem()` (`remote_layout_item_definitions.dart:74-89`):
  gains a `zone` parameter (default `LayoutZone.grid`) so default-set construction can
  stamp "starts positioned" vs. "starts in drawer" per Decisions.

**Implemented as planned (2026-08-21), confirmed by re-read.** One addition beyond this
section's original scope: `LayoutPosition`/`LayoutEditItem` both live in their own files
alongside the new `layout_zone.dart` and `layout_item_id.dart` (the latter added during
Phase 2, see implementation note below) — same one-concept-per-file convention, no deviation.

**Phase 2 — Close the catalog gap uniformly (OCP), not `youtube`-specific.**
Verified precisely this turn: `RemoteCommand` (`remote_command.dart:1-23`) has 21 values; the
union of `requiredCommandsForLayoutItemId`'s switch (pre-Phase-2:
`remote_layout_item_definitions.dart:170-190`) plus `searchInput`'s special-cased
`supportsTextInput` path covers 19 of them. The gap is **exactly and only**
`RemoteCommand.input` and `RemoteCommand.youtube` — a fully closed, verified set, not an
illustrative example. Two moves:
1. Fold `requiredCommandsForLayoutItemId`/`commandForLayoutItemId`'s switch statements into
   declarative fields on `RemoteLayoutItemDefinition` — the OCP cleanup already flagged in
   `goal-variant-remote-layout.md` finding #4 and explicitly slated for this goal in Decisions.
   **As implemented, the fields are `commands: Set<RemoteCommand>` and a derived getter
   `dispatchCommand` (not the `requiredCommands`/`command` names originally sketched here —
   see the Decisions bullet dated 2026-08-21 for the naming rationale).** Adding a new item
   becomes "one list entry," not "touch three places."
2. Add `youtube` and `input` entries to `kRemoteLayoutItemDefinitions`
   (`remote_layout_item_definitions.dart:212-227`) with their commands declared inline.

**Implemented as planned (2026-08-21), confirmed by re-read.** `requiredCommandsForLayoutItemId`
and `commandForLayoutItemId` (`remote_layout_item_definitions.dart:242-249`) are now thin
lookups into `kRemoteLayoutItemDefinitionById[itemId]?.commands` /
`kRemoteLayoutItemDefinitionById[itemId]?.dispatchCommand` — kept as functions rather than
removed since `remote_home_remote_grid.dart` calls `commandForLayoutItemId` directly (a real,
load-bearing external caller, confirmed by read).

**Phase 3 — Placement resolution (SRP: separate "is this eligible" from "where does it render").**
- `buildFilteredRemoteLayoutItems` (`remote_layout_item_definitions.dart:251-276`) currently
  conflates capability eligibility with grid inclusion — an eligible-but-not-default item is
  **omitted** today. Its contract changes to: still capability-filter the same way
  (`supportedCommands.containsAll(definition.commands)`), but an eligible item that isn't in the
  default-positioned set is now **included with `zone: LayoutZone.drawer`** instead of
  dropped.
- New pure, independently-testable function decides each item's starting zone from the
  default-positioned-id set (today: current baseline; later: `RemoteLayoutDefaults` per the
  sibling goal, without this function needing to change shape — DIP against that future swap).
  Same testability rationale that already justified pulling `RemoteLayoutDropResolver` out of
  the editor widget.

**Implemented as planned (2026-08-21), confirmed by `flutter analyze` (clean) and
`flutter test` (402 passed) after the change.** `resolveDefaultLayoutItemZone`
(`remote_layout_item_definitions.dart:251-268`) takes `itemId` and a nullable
`defaultPositionedIds`; `null` (today's only value, everywhere) means "no narrower default
set known yet" and resolves every item to `LayoutZone.grid` — the mechanism exists but
is inert until a real default set is threaded through. `buildFilteredRemoteLayoutItems`
(`:270-300`) gained the matching optional `defaultPositionedIds` parameter and now calls the
resolver once per eligible item instead of always passing `zone: LayoutZone.grid`
implicitly via `toLayoutEditItem()`'s default. No call site in `remote_home_page.dart` passes
`defaultPositionedIds` yet — confirmed unchanged, so this phase does not alter today's
rendered layout, exactly as the caveat above states. That wiring is `goal-variant-remote-layout.md`'s
job.

**Phase 4 — Persistence round-trip** (`remote_home_page.dart`):
- `_persistLayoutForActiveDevice` (`:1145-1157`): add `zone: item.zone` to the
  `LayoutPosition` it already constructs per item. No other shape change.
- `_loadLayoutForDevice` (`:1083-1122`): inside the existing Pro-gated per-item overlay loop
  (`:1100-1116`), add `item.zone = position.zone` alongside the existing `col`/`row`
  overlay — same Tier-0 mechanism, no new resolution path.
- `_resetLayoutToDefaults` (`:1072-1081`) already fully replaces `_layoutItems` wholesale from
  `_buildLayoutDefaultsForDevice`'s output — once Phases 1 and 3 land, zone resets "for
  free" the same way position already does, per the existing claim in Decisions.

**Implemented as planned, with one refinement found during implementation (2026-08-21),
confirmed by `flutter analyze` (clean) and `flutter test` (402 passed).** The overlay loop's
existing `_canPlaceItem` bounds/no-overlap check (`:1105-1112` pre-change) was written for
grid items — it protects the live grid from corrupt or colliding saved `col`/`row` data. A
drawer-zoned item isn't rendered on the grid at all, so gating its `col`/`row` restore behind
a grid-collision check is both meaningless and actively harmful: a drawer item whose saved
spot happens to collide with something now sitting there would silently fail to have its
`col`/`row` restored, quietly undermining the "keep last real position for a future restore"
guarantee from Decisions. Fix: `item.zone = position.zone` is applied unconditionally; the
`_canPlaceItem` gate now only runs when `position.zone == LayoutZone.grid`— unchanged
behavior for grid items, no spurious validation for drawer items.
`domain/domain.dart`'s barrel export also gained `export 'models/layout_zone.dart';`
(alongside the existing `layout_position.dart` export) since `remote_home_page.dart` now
references `LayoutZone` by name and only imported the domain barrel, not the model file
directly.

**Phase 5 — Editor UI (architecture-consistency: extend the existing drag/drop protocol,
don't invent a second one).** *(Bullets below are the pre-implementation plan and keep their
original, now-stale line numbers, same convention as Phases 1-4 above — see "Implemented as
planned" further down for current line numbers and what actually shipped.)*
- `RemoteLayoutEditor.build` (`remote_layout_editor.dart:279-317`): today's `Column` is
  `[header, Expanded(grid canvas)]`. Insert a third fixed-height child for the drawer strip.
  Because it's a permanent `Column` child, not conditionally built, `fitCellSize`'s
  `LayoutBuilder` (`:47-58`) sees a consistently-reduced canvas on every build — the "constant
  presence, no layout jump" requirement from Decisions falls out of this structurally, not from
  extra logic.
- Drawer strip: a horizontally-scrollable list of `Draggable<String>` — one per
  `zone == LayoutZone.drawer` item — reusing `RemoteLayoutEditorItemPreview`
  (already used for grid cells, `:270-277`) for the preview widget, per Decisions.
- Drawer strip root is itself one `DragTarget<String>`; an accepted drop sets
  `item.zone = LayoutZone.drawer` inside `setState`, then
  `unawaited(widget.onPersistLayout())` — the exact same resolve → mutate → `setState` → persist
  shape the grid `DragTarget.onAcceptWithDetails` already uses (`:167`), not a new callback
  contract.
- The existing grid `DragTarget<String>` callbacks (`:107-168`) resolve purely by the dragged
  `movingId` string — they don't need to know whether a drag originated from a grid cell or the
  drawer, **provided** the drawer's `Draggable<String>` carries `data: item.id`, matching the
  grid `Draggable`'s contract. A drawer→grid accepted drop additionally sets
  `item.zone = LayoutZone.grid` alongside the existing `col`/`row` write.

**Implemented as planned, with one correction to the plan found by tracing the resolver
(2026-08-21), confirmed by `flutter analyze` (clean), the full suite (402 passed), and three
throwaway smoke tests exercising the actual drag gestures (drawer renders a parked item;
grid→drawer drag parks and persists; drawer→grid drag restores to the correct cell and
persists) — not committed, Phase 7 owns the permanent tests.**

The doc's original plan said to filter `widget.layoutItems` down to `zone == grid` before
building *both* `occupancyByCell` and `itemsById` (per the "Both previously-flagged items
verified" item #2 above — that section has since been corrected in place too, since it had
asserted the wrong-in-part original plan as settled fact rather than as a plan). Tracing
`RemoteLayoutDropResolver.resolveDrop` (`remote_layout_drop_resolver.dart:736-739`) shows it
does `itemsById[movingId]` and returns `null` if that's absent — so a grid-only `itemsById`
would make every drawer-originated drag unresolvable (the resolver could never find the moving
item). Fix: the two now have different scopes. `occupancyByCell` is built from a
`zone == grid`-filtered `gridItems` list (`remote_layout_editor.dart:171`; this is the actual
occupancy bug-fix) — the render loop consuming that same filtered list is at `:305`. `itemsById`
— the `_itemsById` getter (`:59-61`) — stays **unfiltered**, since it's a pure id lookup with no
occupancy semantics; nothing else needed to change in `RemoteLayoutDropResolver` or
`RemoteLayoutEditorDragSession`, exactly as the doc hoped, just with the filter boundary in a
different place than originally written.

**Follow-up fix (2026-08-21, same day, caught on request for a self-review):** the initial
Phase 5 diff had copy-pasted the same ~60-line `Draggable` drag-lifecycle block (feedback,
childWhenDragging, `Listener`+`onPointerDown`, drag callbacks) once for grid items and once for
drawer items, identical apart from which `cellSize` constant was passed in — a DRY/SRP miss.
Extracted into a shared `_buildDraggableItemPreview({item, cellSize})` (`:80-148`), called from
both the grid render loop (`:309`) and the drawer `itemBuilder` (`:366`). Re-verified
with `flutter analyze` (clean) and all three smoke tests plus the two pre-existing
`remote_layout_editor_widget_test.dart` cases (5/5 passed) after the refactor.

Two new metrics constants (`remote_layout_editor_metrics.dart`): `kRemoteLayoutDrawerStripHeight`
(88, fixed — deliberately not content-sized, so the grid's `fitCellSize` doesn't shift every
time an item enters/leaves the drawer) and `kRemoteLayoutDrawerItemCellSize` (56, independent of
the grid's dynamically-fitted `cellSize`, per the class doc's "may diverge when useful"
allowance). Accepted limitation: a multi-cell item (dpad/volume/channel) parked in the drawer
would render taller than the fixed strip height — considered out of scope since those are core
physical-remote controls, not realistic drawer candidates, and no scaling logic was added for
it. New l10n string `layoutEditorDrawerEmptyHint` (`app_en.arb`), regenerated via
`flutter gen-l10n`.

**Phase 6 — Pro-gating: no new code.** The gate already wraps entry into `RemoteLayoutEditor`
itself; drawer drag is just another drag inside that same gated widget, so it inherits the gate
for free.

**Verified, 2026-08-21 — the `:1084-1087` citation above was stale and pointed at the wrong
code** (that's inside `_loadLayoutForDevice`, Phase 4's territory, unrelated to gating). Traced
the actual mechanism instead of trusting the old citation:
- `_isLayoutEditMode` (`remote_home_page.dart:96`) can only become `true` via
  `_toggleLayoutEditMode()` (`:734-744`), which the app bar action only wires up when
  `canToggleLayout` is true (`:1331-1332`: `_isLayoutEditMode || (_activeDevice != null &&
  isPro)`). A non-Pro user gets `showLayoutLockedOnPress` instead (`:1333-1334`), which shows an
  upsell toast (`_showProLayoutLockedMessage`, `:619-623`) and never flips
  `_isLayoutEditMode`.
- `RemoteLayoutEditor` — grid canvas *and* the Phase 5 drawer strip, as one unit — is only
  constructed when `_isLayoutEditMode` is true (`:1392`: `_isLayoutEditMode ?
  RemoteLayoutEditor(...) : RemoteHomeStatusPanel(...)`). A non-Pro user never has this widget
  in the tree, so the drawer's `DragTarget`/`Draggable` never mount — not hidden, structurally
  absent.
- Edge case checked: a mid-session Pro downgrade (e.g. subscription lapses while the editor is
  open) is already handled by pre-existing code, unrelated to this feature —
  `remote_home_page.dart:215-217` force-exits edit mode the moment `isPro` goes false while
  `_isLayoutEditMode` is true, tearing down the whole editor (drawer included) immediately.

No test added for this gate: it's a pre-existing app-wide mechanism with no test coverage
anywhere in the suite (checked — not command-drawer-specific, out of this goal's scope; Phase 7
below only extends the four files that already cover the drawer's own new surface).

**Testing** — extend the four Phase-0 files rather than add new ones: repository round-trip
(including legacy JSON with no `zone` key → defaults to grid), a drag-to-drawer / drag-
from-drawer widget test, and a grid-constraints check that drawer items don't count toward cell
occupancy.

**Implemented as planned, 2026-08-21, confirmed by the full suite (472 passed, up from 402).**
Three of the four Phase-0 files were extended; the fourth was confirmed to need no changes,
verified rather than assumed:
- `shared_prefs_layout_repository_test.dart`: +2 tests — `zone` round-trips through save/load
  (`LayoutZone.drawer` survives, un-set entries default to `LayoutZone.grid`); a hand-written
  legacy JSON blob with no `"zone"` key at all (simulating pre-Phase-1 persisted data) loads as
  `LayoutZone.grid`.
- `remote_layout_grid_constraints_test.dart`: +1 test — parks `mute` in the drawer, rebuilds
  `occupancyByCell` from the `zone == grid`-filtered list (mirroring what
  `RemoteLayoutEditor._buildLayoutGridCanvas` actually does), and asserts neither `mute`'s id nor
  its old cell key appear in the result.
- `remote_layout_editor_widget_test.dart`: +4 tests — empty-state hint shows/hides correctly;
  simulated `TestGesture` drags (down → move → up, no actual pointer needed) covering both
  directions: dragging a grid item onto the drawer strip (asserts `zone` flips to `drawer`,
  `col`/`row` stay unchanged per Decisions, `onPersistLayout` fires once) and dragging a
  drawer item back onto its own default cell (asserts `zone` flips to `grid`, correct `col`/`row`,
  persist fires). The grid-cell `DragTarget` is targeted via `kRemoteLayoutItemDefinitionById['mute']`'s
  own `col`/`row` rather than a hardcoded cell, so the test stays correct if the catalog's default
  positions ever change.
- `remote_layout_drop_resolver_test.dart`: **no changes — confirmed, not assumed.** Re-read in
  full: every test constructs `LayoutEditItem`s directly (no `zone` field involved in any
  assertion) and calls `RemoteLayoutDropResolver.resolveDrop` with plain `occupancyByCell`/
  `itemsById` maps the test builds itself. The resolver has no zone awareness at all — filtering
  by zone is entirely the caller's job (`RemoteLayoutEditor`), exactly as Phase 5 designed it.

**Both previously-flagged items verified, 2026-08-21:**

1. **Grid `Draggable<String>` data contract — confirmed as assumed.**
   `remote_layout_editor.dart:87` (post-Phase-5; was `:210` pre-Phase-5) — `Draggable<String>(data: item.id, ...)`, now inside the shared `_buildDraggableItemPreview` helper used by both the grid and the drawer strip. A drawer-strip
   `Draggable<String>` reusing `data: item.id` interoperates with the existing grid
   `DragTarget` callbacks with zero changes there, exactly as Phase 5 assumed.

2. **Occupancy map is NOT already filtered — this is a real bug the plan must fix, not an
   open question.** `RemoteLayoutEditorGridGeometry.occupancyByCell`
   (`remote_layout_editor_grid_geometry.dart:22-32`) stamps every item's `col`/`row`/`width`/
   `height` into cells with no zone awareness. Pre-Phase-5, it was called with the **full,
   unfiltered** `widget.layoutItems` (`remote_layout_editor.dart:70-72` in the pre-Phase-5
   file); the `itemsById` map right below it (`:73-75`) and the grid-canvas render loop
   (`for (final item in widget.layoutItems)`, `:203`) did the same. Because Decisions has a
   drawer-parked item **keep** its last real `col`/`row` rather than clearing it, an unfiltered
   occupancy map would let a drawer-parked item keep "occupying" its last grid cell — silently
   blocking other items from being dropped there even though nothing renders there anymore.

   **This item originally claimed the required fix was to filter `widget.layoutItems` down to
   `zone == LayoutZone.grid` before *both* the `occupancyByCell`/`itemsById` construction and
   the render loop, "confirmed necessary rather than assumed." That claim was half right and
   half wrong, corrected during Phase 5 implementation (2026-08-21) — see the "Implemented as
   planned, with one correction" note under Phase 5 above for the full reasoning.** Short
   version: filtering `occupancyByCell` and the render loop to `zone == grid` was correct and
   necessary (that's the actual bug fix). Filtering `itemsById` the same way was **not** —
   `RemoteLayoutDropResolver.resolveDrop` looks up the dragged item via `itemsById[movingId]`,
   so a grid-only `itemsById` would make every drawer-originated drag unresolvable. Current
   state (post-Phase-5, `remote_layout_editor.dart`): `occupancyByCell` built from a
   `gridItems` list filtered to `zone == grid` (`:171`); the render loop iterates that same
   filtered list (`:305`); `itemsById` (the `_itemsById` getter, `:59-61`) stays deliberately
   unfiltered. This is the concrete mechanism behind the original Decisions item 5 ("items with
   `zone: drawer` must be filtered out of the grid-canvas render path"). **Considered and
   rejected: a sentinel `col`/`row` (e.g. `-1`/`-999`) instead of the filter** — this would
   overwrite the real last-known position Decisions already chose to preserve (per user: "persist
   the original row,col if we ever want to use it"), and reintroduces the exact "reserved
   out-of-bounds value every consumer must special-case" smell the `zone` field was
   introduced to eliminate in place of the earlier sentinel-position proposal. The filter keeps
   `col`/`row` always real; `zone` alone (already explicit, not a magic number) governs
   occupancy.

## Post-implementation findings from real-device manual testing (2026-08-21)

All 7 phases passed automated tests but had never been exercised on an actual touchscreen
against a real TV until this pass. Three issues surfaced, all fixed and re-verified
(`flutter analyze` clean, full suite 474 passed, up from 472):

1. **Bug (severity: high) — a drawer-parked item never actually disappeared from the live
   remote screen, only from the editor.** `RemoteHomeRemoteGrid` (the non-edit-mode, everyday
   remote view — `remote_home_remote_grid.dart`) rendered `for (final item in layoutItems)`
   with **zero `zone` filtering**; it didn't even import `layout_zone.dart`. Phase 5 only fixed
   the *editor's* grid canvas — this second consumer of the same shared `_layoutItems` list was
   missed entirely. Fixed: added a `gridItems = layoutItems.where((item) => item.zone ==
   LayoutZone.grid)` filter before the render loop (`remote_home_remote_grid.dart`), mirroring
   the editor's existing fix. Added `remote_home_remote_grid_test.dart` (new file — this widget
   had no dedicated test coverage at all before this) with a positive and negative case; this is
   exactly the kind of regression this class of bug needs to keep from recurring.
2. **Doc gap — the editor's instruction text never mentioned the drawer.**
   `layoutEditorInstruction` (`app_en.arb`) said only "Drag buttons to new positions. Grid lines
   show cells; a green outline means the drop is allowed." Updated to: "Drag buttons to new
   positions, or into the strip below to remove them from your remote. Grid lines show cells; a
   green outline means the drop is allowed." Regenerated via `flutter gen-l10n`.
3. **UX gap — the drawer strip had no way to scroll it and no indication scrolling was
   possible.** Root cause: a plain `Draggable` inside a `ListView` of the same scroll axis wins
   the gesture arena over the list's own scroll recognizer, so a swipe over any item is consumed
   as a (failed) drag attempt instead of scrolling — and since the strip is mostly covered by
   item tiles, there was barely any "dead space" left to swipe from. First fix attempt used
   `LongPressDraggable` for drawer items only (quick swipe scrolls, a deliberate hold drags) —
   works, but reintroduces exactly the interaction-language inconsistency Decisions had
   deliberately avoided ("one interaction language throughout edit mode — drag between zones");
   grid items stay instant-drag while drawer items would need a hold, an asymmetry the user
   flagged as unnecessary. **Superseded, same day:** reverted to plain `Draggable` for drawer
   items too (identical to grid — `_buildDraggableItemPreview` has no branching now), and instead
   wrapped the drawer's `ListView` in a `Scrollbar(thumbVisibility: true, interactive: true)`.
   The scrollbar thumb is a separate touch target from the item tiles, so it never competes with
   `Draggable` in the gesture arena — solves both the "can't scroll" and "no indication scrolling
   is possible" complaints without touching the drag interaction at all. Needed a
   `ScrollController` field + `dispose()` override on `_RemoteLayoutEditorState` (didn't
   previously have one).

## Drawer strip redesign, round 2 of real-device testing (2026-08-21)

Real-device testing surfaced a sizing regression I introduced while fixing the earlier overflow
bug (see "Post-implementation findings" above): I shrank `kRemoteLayoutDrawerItemCellSize`
(56→44) and `kRemoteLayoutDrawerStripHeight` (88→60) reflexively while chasing the overflow
number, without checking whether the smaller sizes were still comfortable for a human — a fair
callout. Re-tested with the *original* drawer values after the real fix (the instruction
text — see below) landed, and they passed cleanly even at 320×700. **The drawer was never the
problem; reverted `kRemoteLayoutDrawerItemCellSize`/`kRemoteLayoutDrawerStripHeight` back to
88/56, unchanged from before.**

The actual overflow cause: `layoutEditorInstruction`'s replacement text was 58% longer than the
original, and the *original* text was already marginally too tall for the header's fixed 106px
budget at narrow widths (a pre-existing, latent issue, confirmed by measuring the exact original
string in isolation — 118px needed vs. 106px budget at 328px content width). Iterated the
replacement text down through several drafts, each measured directly against the real widget
render (not a bare `TextPainter` — an early attempt used one with a test-only fallback font that
doesn't match production Roboto metrics and gave misleading numbers) until landing on "Drag to
reposition, or drop below to remove." (46 chars), which fits without truncation on any phone
≥360dp wide. Also added `maxLines: 2, overflow: TextOverflow.ellipsis` as a permanent safety net
so this text can never produce a visible overflow crash again, regardless of device width or
font-scaling settings — on the shrinking minority of devices ≤320dp it now truncates gracefully
instead.

Separately, per user feedback, redesigned the drawer strip's interaction model:
- **Drawer row width now exactly matches the grid's width** (previously stretched to the full
  editor width, which was wider than the grid on any device where the grid is height- rather
  than width-constrained — the common case in portrait). Required lifting `cellSize`/`gridWidth`
  computation out of `_buildLayoutGridCanvas`'s own `LayoutBuilder` into one `LayoutBuilder`
  wrapping the whole `build()` — needed so the drawer strip (built as a sibling, not a descendant
  of the grid canvas) can be sized to the identical value. `_buildLayoutGridCanvas` no longer has
  its own `LayoutBuilder`; it takes `cellSize`/`gridWidth` as parameters instead.
- **Removed the `Scrollbar`, replaced with two triangle buttons** (`Icons.arrow_left`/
  `Icons.arrow_right`) outside the drawer box, sized so `2 * (chevronSize + chevronGap)` plus the
  box width equals `gridWidth` exactly — no fallback path needed for width-constrained devices,
  since the triangles are carved out of the same budget the drawer already had (it used to be
  wider than the grid; now that surplus funds the triangles instead of empty stretch space).
  Tap scrolls by exactly one item's width (`kRemoteLayoutDrawerItemCellSize + gridGap`); holding
  scrolls continuously via a `Timer.periodic` (`kRemoteLayoutDrawerAutoScrollTickInterval` =
  16ms, `kRemoteLayoutDrawerAutoScrollPixelsPerTick` = 6) until released. New state:
  `Timer? _drawerAutoScrollTimer`, cancelled in both `onLongPressEnd`/`onLongPressCancel` and
  `dispose()`.
- Drawer items remain plain `Draggable` (not `LongPressDraggable`) — the triangle buttons are a
  separate touch target from the item tiles, so there was never a gesture-arena conflict to
  design around here in the first place, unlike the earlier (reverted) scrollbar-thumb-vs-drag
  investigation.

New metrics (`remote_layout_editor_metrics.dart`): `kRemoteLayoutDrawerChevronSize` (36, meets
common ~44dp touch-target guidance closely enough while leaving most of the width budget to the
box), `kRemoteLayoutDrawerChevronGap` (4), `kRemoteLayoutDrawerAutoScrollPixelsPerTick` (6),
`kRemoteLayoutDrawerAutoScrollTickInterval` (16ms).

Verified: `flutter analyze` clean; full suite 478 passed (up from 475). Added 3 permanent tests
to `remote_layout_editor_widget_test.dart`'s drawer group — drawer-row-width-equals-grid-width,
tap-scrolls-exactly-one-item (asserts the scroll position delta equals
`kRemoteLayoutDrawerItemCellSize + gridGap` precisely, not just "some movement"), and
hold-scrolls-further-than-a-tap. All three assert against the real `Scrollable`'s
`ScrollableState.position.pixels`, not fragile item-visibility checks — an early draft tracking
a specific item's on-screen position failed when that item scrolled outside the `ListView`'s
retained cache window after just one tap, which is what led to the more robust approach.

## Open questions

None remaining for this goal — both prior questions resolved (see Decisions). Remaining dependency: `goal-variant-remote-layout.md`'s physical-remote source data determines each variant's actual default set.

## Relationship to `goal-variant-remote-layout.md`

Both features touch the same layout data model (`LayoutRepository`, `kRemoteLayoutItemDefinitions`, `buildFilteredRemoteLayoutItems`). Recommend deciding both designs together before implementing either, to avoid a rework where the per-variant-default work lands first and the drawer work then has to retrofit an excluded-items concept on top of it (or vice versa).

---
