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

1. ~~**No drawer-equivalent exists today.** `LayoutPosition` (`lib/remote_control/domain/models/layout_position.dart:2-21`) holds only `col`/`row` — no visible/hidden/enabled field of any kind.~~ **Superseded by Phase 1 (2026-08-21): `LayoutPosition` (`layout_position.dart:4-35`) now also holds `category: LayoutCategory` (`grid`/`drawer`)** — this is the drawer-equivalent field this fact originally found missing.
2. ~~**`LayoutEditItem`** (`lib/remote_control/presentation/widgets/layout_edit_item.dart:4-26`) — the mutable runtime item — also has no enabled/disabled/hidden field. Checked in full; confirmed absent.~~ **Superseded by Phase 1 (2026-08-21): `LayoutEditItem` (`layout_edit_item.dart:5-28`) now has a mutable `category: LayoutCategory` field**, mirroring `LayoutPosition`.
3. ~~**Layout catalog is fixed and global.** `kRemoteLayoutItemDefinitions` (`lib/remote_control/presentation/widgets/remote_layout_item_definitions.dart:67-156`) is a hardcoded list of 14 item ids (power, menu, volume, playPause, www, dpad, channel, home, back, mute, netflix, disney, prime, searchInput) with fixed grid geometry — same for every brand.~~ **Superseded by Phase 2 (2026-08-21): the catalog now has 16 items** (`remote_layout_item_definitions.dart:92-228`) — the original 14 plus `youtube` and `input`. Still fixed/global (same list for every brand) — only the count changed.
4. **Filtering is capability-only, not user choice.** `buildFilteredRemoteLayoutItems` (`remote_layout_item_definitions.dart:251-276`) includes an item only if `supportedCommands.containsAll(definition.commands)` (or `supportsTextInput` for `searchInput`). An unsupported command's item is **fully omitted** — never rendered anywhere, not even as disabled. (Still true post-Phase-2; this is exactly what Phase 3 changes.)
5. ~~**Proof of the gap:** `RemoteCommand.youtube` and `RemoteCommand.input` (`lib/remote_control/domain/models/remote_command.dart:9,14`) are valid, dispatchable commands — `youtube` is in `kCommonSupportedRemoteCommands` (`supported_remote_commands.dart:17`) and wired into every adapter's key mapper — but **neither has a case in `requiredCommandsForLayoutItemId` or `commandForLayoutItemId`** (`remote_layout_item_definitions.dart:170-209`). They are unreachable from any UI today — not hidden, just absent.~~ **Fixed by Phase 2 (2026-08-21):** both now have catalog entries (`youtube` at `remote_layout_item_definitions.dart:212-218`, `input` at `:221-227`) with `commands: {RemoteCommand.youtube}` / `{RemoteCommand.input}`. They render on the main grid today for any device whose adapter supports them — see the Phase 3 caveat below for why that's still not the intended end state.
6. **"Command exists for this device" = "command is in the resolved adapter's `supportedCommands` set."** `BrandRoutedRemoteCommandService._adapterFor(brand, variant)` (`lib/remote_control/data/brand_routed_remote_command_service.dart:278-279`) does a `Map<(TvBrand, String), TvBrandAdapter>` lookup; `supportedCommandsFor(device)` delegates straight to that adapter's `supportedCommands` getter. This is already the source of truth the drawer would key off of — no new "does this command exist" logic is needed, only a new "is it currently excluded from the layout by user choice" state.
7. **Per-adapter command sets differ** (confirmed by direct read of each adapter file):
   - `android_tv`, `tcl_google_tv` (`TvBrand.tcl`, variant `googleTv`), `samsung`, `hisense`, `lg` all use the shared `kCommonSupportedRemoteCommands` (21/21 `RemoteCommand` values — i.e. this set is currently the *entire* enum, not a curated subset).
   - `TclRokuAdapter` (**`TvBrand.roku`**, its own top-level brand — not a TCL variant, despite the filename `tcl_roku_adapter.dart`) defines its own 20-command set, excluding `RemoteCommand.web` (`tcl_roku_adapter.dart:25-46,49`).
   - `TclLegacyWifiAdapter` (`TvBrand.tcl`, variant `legacyWifi`) defines a further-restricted 16-command set with **zero app-shortcut commands** (`tcl_legacy_wifi_adapter.dart:19-36`).

## Proposed design (undecided — for discussion)

1. ~~Extend the persisted layout state to separate positioned/visible items from a known-but-drawer-parked set~~ — **resolved, see Decisions: `LayoutPosition.category` (`LayoutCategory.grid`/`LayoutCategory.drawer`) field chosen.**
2. ~~Extend `kRemoteLayoutItemDefinitions`/`requiredCommandsForLayoutItemId`/`commandForLayoutItemId` to cover every `RemoteCommand` that any adapter's `supportedCommands` set can produce (per `TvCapabilities`/adapter `supportedCommands`, verified fact #6) — uniformly, not a special case for `youtube`/`input`. Verified fact #5 (`youtube`/`input` currently unreachable) is one instance of this gap, not the whole of it; the fix should cover every command the layout catalog is currently missing so any capability-supported command can have a drawer representation.~~ — **resolved by Phase 2 (2026-08-21): see Decisions for the `commands`/`dispatchCommand` field design that replaced the two switch statements, and Verified fact #5 above for the `youtube`/`input` closure.**
3. ~~A UI surface (drawer strip within the editor) listing capability-supported-but-not-placed items, with add/remove actions~~ — **resolved, see "Proposed UX design — drawer interaction" below: a fixed, always-visible drawer strip, drag-based add/remove in both directions.** (`remote_layout_editor.dart` currently only supports drag-repositioning of items already present — no picker exists yet; grepped for `remove|delete|hide|drawer|overflow|toggle`, no relevant hits — confirms this is genuinely new UI, not an extension of an existing picker.)
4. Small, non-breaking `SharedPreferences` shape addition — `LayoutPosition` gains `category` (an enum, default `LayoutCategory.grid` when absent), per Decisions below. No migration script needed; existing persisted data reads correctly under the new default.

## Decisions

- **Terminology:** "positioned" = an item with `category: LayoutCategory.grid` (or absent, defaulting to `LayoutCategory.grid`) in `LayoutRepository`'s `Map<String, LayoutPosition>` (`layout_repository.dart:4`) — i.e. currently placed/visible on the grid at its `col`/`row`. "Drawer" = adapter-`supportedCommands` items that are either absent from that map, or present with `category: LayoutCategory.drawer`.
- 2026-08-20 (**revised** — see next bullet): ~~Design option (b), fully derived, no persisted field~~ superseded. Pure derivation (absence = drawer) has a real edge case: if a Pro user drags *every* item out of the grid, the saved-positions map goes empty, and the app currently infers "empty map = never customized" (`_loadLayoutForDevice`, verified fact #9 in `goal-variant-remote-layout.md`) — so on next load it would silently repopulate the full default set, undoing the user's explicit choice.
- 2026-08-20 (**superseded by next bullet**): ~~drawer state persists via a sentinel `col: -1, row: -1` position~~ — replaced with a proper field, see below.
- 2026-08-21 (**revised same day**): ~~`LayoutPosition` gains a new `bool inDrawer` field~~ superseded — **`LayoutPosition` gains an `enum LayoutCategory { grid, drawer }` field named `category` instead of a bare `bool`.** Same underlying schema change (one new field, non-breaking, defaults correctly for already-persisted data — absent `category` reads as `LayoutCategory.grid`, matching the fact that nothing shipped has ever been drawer-parked), but per user feedback an enum reads clearer at call sites (`position.category == LayoutCategory.drawer` vs. a bare `true`/`false`) and leaves room for a future third category without another boolean bolted on later. A drawer-parked command sets `category: LayoutCategory.drawer` and **keeps its last real `col`/`row`** instead of losing it — preserved in case a future "restore to last spot" convenience is wanted, per user: "persist the original row,col if we ever want to use it." Restoring sets `category: LayoutCategory.grid`; whether the drop then reuses the preserved position as a suggestion or the user just drags to a fresh cell is a smaller UI decision, not blocked by this data choice either way. This also still resolves the magic-number tradeoff flagged against the earlier sentinel-position approach — no reserved out-of-bounds value to remember, and now no bare boolean either.
- 2026-08-20: **Default drawer-vs-positioned state for any command (including `youtube`/`input`) matches that `(brand, variant)`'s default set**, per the `RemoteLayoutDefaults` map defined in `goal-variant-remote-layout.md` (see that doc for what determines the default set — no longer strictly physical-remote-bound, see its latest revision). A command starts positioned if it's in that variant's default set; starts in the drawer if the adapter supports it but the default set doesn't include it. This makes the drawer's default state a direct consequence of variant-layout's data, not an independent decision here.
- 2026-08-20: **Pro-gating, confirmed:** editing/repositioning — including drawer drag-in/drag-out, since that's a position edit — is **Pro-only**, matching the existing layout-editor gate (`remote_home_page.dart:1084-1087`). The *default* command set itself (which commands a free user sees, per their device's brand+variant) is **not** Pro-gated — showing the correct commands for a device is a correctness matter, not a customization perk, and matches how defaults already work for everyone today.
- 2026-08-21: **`RemoteLayoutItemDefinition`'s OCP fields are named `commands: Set<RemoteCommand>` and a derived getter `dispatchCommand`, not the originally-planned `requiredCommands`/`command`.** Per user feedback during Phase 2 (`RemoteLayoutItemDefinition` was hard to read with two similarly-named-but-differently-purposed fields): `commands` holds every `RemoteCommand` the device must support for the item to appear at all (empty means "not gated by a command" — today only `searchInput`, gated by `supportsTextInput` instead). `dispatchCommand` is **not a stored field** — it's `commands.length == 1 ? commands.single : null`, computed on read. Storing it separately was rejected: `dpad`/`volume`/`channel` need multiple `commands` but have no single "the tap action" (their sub-controls dispatch individually), and a second stored field for the single-command case would reopen the exact split-registry-drift failure mode that originally caused `youtube`/`input` to go missing from one switch statement while present in the other (verified fact #5, pre-fix). Verified against all 16 catalog items with zero counterexamples; documented limitation: a future item needing >1 required command but exactly 1 dispatch command would need a real (non-derived) field — no such item exists today.
- 2026-08-20: **Build this goal first, before `goal-variant-remote-layout.md`, confirmed.** This work already touches every entry in `kRemoteLayoutItemDefinitions` (extending coverage to `youtube`/`input`) and is the natural point to fold `requiredCommandsForLayoutItemId`/`commandForLayoutItemId` into declarative fields on `RemoteLayoutItemDefinition` (OCP cleanup — see design review in `goal-variant-remote-layout.md` finding #4). The variant-layout goal then seeds its per-`(brand,variant)` catalogs from this goal's finished shape, avoiding rework.
- 2026-08-21: **Persist-on-change and reset-to-default already exist for positions and extend naturally** to `category`-flagged entries — no new save/load pathway, just one more field riding along with the values already flowing through it:
  - `RemoteLayoutEditor.onAcceptWithDetails` already calls `widget.onPersistLayout()` on every accepted drop (`remote_layout_editor.dart:167`) — auto-save per change, no separate save step; a drag-to-drawer persists the same entry with `category: LayoutCategory.drawer` and its `col`/`row` unchanged.
  - The editor header's `restart_alt` icon already wires to `_resetLayoutForActiveDevice()` → `_resetLayoutToDefaults()` → re-persists the cleared state (`remote_home_page.dart:1159-1167`, `1072-1081`); reset replaces the whole map with the default profile's real positions (`category: LayoutCategory.grid` throughout), so no leftover drawer-parked entries survive a reset.

## Proposed UX design — drawer interaction (revised 2026-08-20 per user feedback)

Grounded directly in `remote_layout_editor.dart` and `remote_home_page.dart` (pencil icon = `Icons.edit_outlined` in `remote_home_app_bar_actions.dart:31` → `_toggleLayoutEditMode`, confirmed).

1. **Always visible during edit mode — no toggle icon, no open/close step.** The earlier icon-triggered-overlay proposal added a tap the user has to discover before they can even use the drawer. That protection wasn't actually needed: the "cancel edit" control (the pencil icon, `Icons.edit_outlined`) lives in the app bar (`remote_home_app_bar_actions.dart`), **outside** `RemoteLayoutEditor` entirely — there was never a collision to guard against. Instead, add the drawer as a **fixed, permanently-present region** in `RemoteLayoutEditor.build`'s existing `Column` (`remote_layout_editor.dart:283-318`) — e.g. a slim horizontally-scrollable strip between the header and the grid canvas. Because it's never toggled on/off during an edit session, `RemoteLayoutEditorGridGeometry.fitCellSize` computes the grid's available space once, consistently, for the whole session — "not intrusive to positioning" is satisfied by the drawer's presence being constant, not by a show/hide mechanic.
2. **Both remove and restore are drag, not tap.** Tap-to-restore was rejected earlier: the item would place itself automatically somewhere in the grid the user didn't choose, "confusing... you'll need to look for it." Drag keeps the destination visible and user-chosen, consistent with how repositioning already works.
   - **Remove (grid → drawer):** the drawer strip is a `DragTarget<String>` — the user drags a grid item (already `Draggable<String>`, no new widget needed) into it to park it (sets `category: LayoutCategory.drawer`, keeps `col`/`row` as-is, per Decisions above).
   - **Restore (drawer → grid):** drawer items are also `Draggable<String>` (reusing `RemoteLayoutEditorItemPreview` for feedback/preview, same as grid items) — the user drags one out onto a chosen grid cell. Grid cells' existing `DragTarget<String>` (`remote_layout_editor.dart:105-168`) already validates footprint/occupancy via `RemoteLayoutEditorDragSession`/`RemoteLayoutEditorGridGeometry` — no new validation logic needed, the drop just needs to also accept drags originating from the drawer, not only from other grid cells.
   - One interaction language throughout edit mode — drag between zones — no separate tap-badge gesture to learn.
3. Both directions call `onPersistLayout()` immediately, matching the existing auto-persist-on-change pattern. Empty-state text in the drawer ("Drag a command here to remove it from your remote") for discoverability.
4. Drawer items reuse `RemoteLayoutEditorItemPreview` (already used for grid items and drag feedback) — no new preview widget needed, visual consistency for free.
5. Items with `category: LayoutCategory.drawer` must be filtered out of the grid-canvas render path and routed to the drawer strip's render path instead — the one new bit of rendering logic this design needs.

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
- New `enum LayoutCategory { grid, drawer }`, own file, matching the one-concept-per-file
  convention already used by `layout_position.dart` / `layout_edit_item.dart`.
- `LayoutPosition` (`layout_position.dart:4-35`): add `final LayoutCategory category`,
  default `LayoutCategory.grid`. `toJson` adds `'category': category.name`; `fromJson` parses
  defensively and falls back to `LayoutCategory.grid` when the key is absent or unrecognized —
  preserves the non-breaking guarantee already recorded in Decisions (old persisted blobs have
  no `category` key at all).
- `LayoutEditItem` (`layout_edit_item.dart:5-28`): mirror with a **mutable** `category` field
  (mutable like `col`/`row`, since drag operations flip it live) — this is the type the running
  editor actually reads from (`_layoutItems`, `remote_home_page.dart:92`), so the runtime model
  needs the field independently of the persisted one.
- `RemoteLayoutItemDefinition.toLayoutEditItem()` (`remote_layout_item_definitions.dart:74-89`):
  gains a `category` parameter (default `LayoutCategory.grid`) so default-set construction can
  stamp "starts positioned" vs. "starts in drawer" per Decisions.

**Implemented as planned (2026-08-21), confirmed by re-read.** One addition beyond this
section's original scope: `LayoutPosition`/`LayoutEditItem` both live in their own files
alongside the new `layout_category.dart` and `layout_item_id.dart` (the latter added during
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
  default-positioned set is now **included with `category: LayoutCategory.drawer`** instead of
  dropped.
- New pure, independently-testable function decides each item's starting category from the
  default-positioned-id set (today: current baseline; later: `RemoteLayoutDefaults` per the
  sibling goal, without this function needing to change shape — DIP against that future swap).
  Same testability rationale that already justified pulling `RemoteLayoutDropResolver` out of
  the editor widget.

**Phase 4 — Persistence round-trip** (`remote_home_page.dart`):
- `_persistLayoutForActiveDevice` (`:1145-1157`): add `category: item.category` to the
  `LayoutPosition` it already constructs per item. No other shape change.
- `_loadLayoutForDevice` (`:1083-1122`): inside the existing Pro-gated per-item overlay loop
  (`:1100-1116`), add `item.category = position.category` alongside the existing `col`/`row`
  overlay — same Tier-0 mechanism, no new resolution path.
- `_resetLayoutToDefaults` (`:1072-1081`) already fully replaces `_layoutItems` wholesale from
  `_buildLayoutDefaultsForDevice`'s output — once Phases 1 and 3 land, category resets "for
  free" the same way position already does, per the existing claim in Decisions.

**Phase 5 — Editor UI (architecture-consistency: extend the existing drag/drop protocol,
don't invent a second one).**
- `RemoteLayoutEditor.build` (`remote_layout_editor.dart:279-317`): today's `Column` is
  `[header, Expanded(grid canvas)]`. Insert a third fixed-height child for the drawer strip.
  Because it's a permanent `Column` child, not conditionally built, `fitCellSize`'s
  `LayoutBuilder` (`:47-58`) sees a consistently-reduced canvas on every build — the "constant
  presence, no layout jump" requirement from Decisions falls out of this structurally, not from
  extra logic.
- Drawer strip: a horizontally-scrollable list of `Draggable<String>` — one per
  `category == LayoutCategory.drawer` item — reusing `RemoteLayoutEditorItemPreview`
  (already used for grid cells, `:270-277`) for the preview widget, per Decisions.
- Drawer strip root is itself one `DragTarget<String>`; an accepted drop sets
  `item.category = LayoutCategory.drawer` inside `setState`, then
  `unawaited(widget.onPersistLayout())` — the exact same resolve → mutate → `setState` → persist
  shape the grid `DragTarget.onAcceptWithDetails` already uses (`:167`), not a new callback
  contract.
- The existing grid `DragTarget<String>` callbacks (`:107-168`) resolve purely by the dragged
  `movingId` string — they don't need to know whether a drag originated from a grid cell or the
  drawer, **provided** the drawer's `Draggable<String>` carries `data: item.id`, matching the
  grid `Draggable`'s contract. A drawer→grid accepted drop additionally sets
  `item.category = LayoutCategory.grid` alongside the existing `col`/`row` write.

**Phase 6 — Pro-gating: no new code.** The gate already wraps entry into `RemoteLayoutEditor`
itself (`remote_home_page.dart:1084-1087`); drawer drag is just another drag inside that same
gated widget, so it inherits the gate for free.

**Testing** — extend the four Phase-0 files rather than add new ones: repository round-trip
(including legacy JSON with no `category` key → defaults to grid), a drag-to-drawer / drag-
from-drawer widget test, and a grid-constraints check that drawer items don't count toward cell
occupancy.

**Both previously-flagged items verified, 2026-08-21:**

1. **Grid `Draggable<String>` data contract — confirmed as assumed.**
   `remote_layout_editor.dart:210` — `Draggable<String>(data: item.id, ...)`. A drawer-strip
   `Draggable<String>` reusing `data: item.id` interoperates with the existing grid
   `DragTarget` callbacks with zero changes there, exactly as Phase 5 assumed.

2. **Occupancy map is NOT already filtered — this is a real bug the plan must fix, not an
   open question.** `RemoteLayoutEditorGridGeometry.occupancyByCell`
   (`remote_layout_editor_grid_geometry.dart:22-32`) stamps every item's `col`/`row`/`width`/
   `height` into cells with no category awareness. It's called at
   `remote_layout_editor.dart:70-72` with the **full, unfiltered** `widget.layoutItems`; the
   `itemsById` map right below it (`:73-75`) and the grid-canvas render loop
   (`for (final item in widget.layoutItems)`, `:203`) do the same. Because Decisions has a
   drawer-parked item **keep** its last real `col`/`row` rather than clearing it, an unfiltered
   list means a drawer-parked item would keep "occupying" its last grid cell — silently
   blocking other items from being dropped there even though nothing renders there anymore.
   **Required fix, folded into Phase 5:** filter `widget.layoutItems` down to
   `category == LayoutCategory.grid` before both the `occupancyByCell`/`itemsById`
   construction (`:70-75`) and the Positioned-item render loop (`:203`) — one `.where` clause
   reused at both sites. This is the concrete mechanism behind the original Decisions item 5
   ("items with `category: drawer` must be filtered out of the grid-canvas render path"), now
   pinned to exact line numbers and confirmed necessary rather than assumed. **Considered and
   rejected: a sentinel `col`/`row` (e.g. `-1`/`-999`) instead of the filter** — this would
   overwrite the real last-known position Decisions already chose to preserve (per user: "persist
   the original row,col if we ever want to use it"), and reintroduces the exact "reserved
   out-of-bounds value every consumer must special-case" smell the `category` field was
   introduced to eliminate in place of the earlier sentinel-position proposal. The filter keeps
   `col`/`row` always real; `category` alone (already explicit, not a magic number) governs
   occupancy.

## Open questions

None remaining for this goal — both prior questions resolved (see Decisions). Remaining dependency: `goal-variant-remote-layout.md`'s physical-remote source data determines each variant's actual default set.

## Relationship to `goal-variant-remote-layout.md`

Both features touch the same layout data model (`LayoutRepository`, `kRemoteLayoutItemDefinitions`, `buildFilteredRemoteLayoutItems`). Recommend deciding both designs together before implementing either, to avoid a rework where the per-variant-default work lands first and the drawer work then has to retrofit an excluded-items concept on top of it (or vice versa).

---
