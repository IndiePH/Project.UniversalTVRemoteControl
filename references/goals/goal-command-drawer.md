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

1. **No drawer-equivalent exists today.** `LayoutPosition` (`lib/remote_control/domain/models/layout_position.dart:2-21`) holds only `col`/`row` — no visible/hidden/enabled field of any kind.
2. **`LayoutEditItem`** (`lib/remote_control/presentation/widgets/layout_edit_item.dart:4-26`) — the mutable runtime item — also has no enabled/disabled/hidden field. Checked in full; confirmed absent.
3. **Layout catalog is fixed and global.** `kRemoteLayoutItemDefinitions` (`lib/remote_control/presentation/widgets/remote_layout_item_definitions.dart:67-156`) is a hardcoded list of 14 item ids (power, menu, volume, playPause, www, dpad, channel, home, back, mute, netflix, disney, prime, searchInput) with fixed grid geometry — same for every brand.
4. **Filtering is capability-only, not user choice.** `buildFilteredRemoteLayoutItems` (`remote_layout_item_definitions.dart:211-236`) includes an item only if `supportedCommands.containsAll(requiredCommandsForLayoutItemId(id))` (or `supportsTextInput` for `searchInput`). An unsupported command's item is **fully omitted** — never rendered anywhere, not even as disabled.
5. **Proof of the gap:** `RemoteCommand.youtube` and `RemoteCommand.input` (`lib/remote_control/domain/models/remote_command.dart:9,14`) are valid, dispatchable commands — `youtube` is in `kCommonSupportedRemoteCommands` (`supported_remote_commands.dart:17`) and wired into every adapter's key mapper — but **neither has a case in `requiredCommandsForLayoutItemId` or `commandForLayoutItemId`** (`remote_layout_item_definitions.dart:170-209`). They are unreachable from any UI today — not hidden, just absent.
6. **"Command exists for this device" = "command is in the resolved adapter's `supportedCommands` set."** `BrandRoutedRemoteCommandService._adapterFor(brand, variant)` (`lib/remote_control/data/brand_routed_remote_command_service.dart:278-279`) does a `Map<(TvBrand, String), TvBrandAdapter>` lookup; `supportedCommandsFor(device)` delegates straight to that adapter's `supportedCommands` getter. This is already the source of truth the drawer would key off of — no new "does this command exist" logic is needed, only a new "is it currently excluded from the layout by user choice" state.
7. **Per-adapter command sets differ** (confirmed by direct read of each adapter file):
   - `android_tv`, `tcl_google_tv` (`TvBrand.tcl`, variant `googleTv`), `samsung`, `hisense`, `lg` all use the shared `kCommonSupportedRemoteCommands` (21/21 `RemoteCommand` values — i.e. this set is currently the *entire* enum, not a curated subset).
   - `TclRokuAdapter` (**`TvBrand.roku`**, its own top-level brand — not a TCL variant, despite the filename `tcl_roku_adapter.dart`) defines its own 20-command set, excluding `RemoteCommand.web` (`tcl_roku_adapter.dart:25-46,49`).
   - `TclLegacyWifiAdapter` (`TvBrand.tcl`, variant `legacyWifi`) defines a further-restricted 16-command set with **zero app-shortcut commands** (`tcl_legacy_wifi_adapter.dart:19-36`).

## Proposed design (undecided — for discussion)

1. ~~Extend the persisted layout state to separate positioned/visible items from a known-but-drawer-parked set~~ — **resolved, see Decisions: `LayoutPosition.inDrawer` field chosen.**
2. Extend `kRemoteLayoutItemDefinitions`/`requiredCommandsForLayoutItemId`/`commandForLayoutItemId` to cover every `RemoteCommand`, starting with `youtube` and `input`, so they have *some* layout representation to place in the drawer.
3. A UI surface (drawer strip within the editor) listing capability-supported-but-not-placed items, with add/remove actions. `remote_layout_editor.dart` currently only supports drag-repositioning of items already present — no picker exists (grepped for `remove|delete|hide|drawer|overflow|toggle`, no relevant hits).
4. Small, non-breaking `SharedPreferences` shape addition — `LayoutPosition` gains `inDrawer` (default `false` when absent), per Decisions below. No migration script needed; existing persisted data reads correctly under the new default.

## Decisions

- **Terminology:** "positioned" = an item with `inDrawer: false` (or absent, defaulting false) in `LayoutRepository`'s `Map<String, LayoutPosition>` (`layout_repository.dart:4`) — i.e. currently placed/visible on the grid at its `col`/`row`. "Drawer" = adapter-`supportedCommands` items that are either absent from that map, or present with `inDrawer: true`.
- 2026-08-20 (**revised** — see next bullet): ~~Design option (b), fully derived, no persisted field~~ superseded. Pure derivation (absence = drawer) has a real edge case: if a Pro user drags *every* item out of the grid, the saved-positions map goes empty, and the app currently infers "empty map = never customized" (`_loadLayoutForDevice`, verified fact #9 in `goal-variant-remote-layout.md`) — so on next load it would silently repopulate the full default set, undoing the user's explicit choice.
- 2026-08-20 (**superseded by next bullet**): ~~drawer state persists via a sentinel `col: -1, row: -1` position~~ — replaced with a proper field, see below.
- 2026-08-21: **`LayoutPosition` gains a new `bool inDrawer` field (default `false`), rather than a sentinel position.** A drawer-parked command sets `inDrawer: true` and **keeps its last real `col`/`row`** instead of losing it — preserved in case a future "restore to last spot" convenience is wanted, per user: "persist the original row,col if we ever want to use it." Restoring sets `inDrawer: false`; whether the drop then reuses the preserved position as a suggestion or the user just drags to a fresh cell is a smaller UI decision, not blocked by this data choice either way. This **is** a schema change (`LayoutPosition.toJson`/`fromJson` gain the field) — revises the earlier "zero schema change" framing — but it's non-breaking: any already-persisted `{col, row}` blob from the currently-shipped editor reads `inDrawer` as `false` by default, which is correct for that data (nothing shipped has ever been drawer-parked). This also resolves the magic-number tradeoff flagged against the sentinel approach — an explicit boolean reads clearly, no reserved out-of-bounds value to remember.
- 2026-08-20: **Default drawer-vs-positioned state for any command (including `youtube`/`input`) matches that `(brand, variant)`'s default set**, per the `RemoteLayoutDefaults` map defined in `goal-variant-remote-layout.md` (see that doc for what determines the default set — no longer strictly physical-remote-bound, see its latest revision). A command starts positioned if it's in that variant's default set; starts in the drawer if the adapter supports it but the default set doesn't include it. This makes the drawer's default state a direct consequence of variant-layout's data, not an independent decision here.
- 2026-08-20: **Pro-gating, confirmed:** editing/repositioning — including drawer drag-in/drag-out, since that's a position edit — is **Pro-only**, matching the existing layout-editor gate (`remote_home_page.dart:1084-1087`). The *default* command set itself (which commands a free user sees, per their device's brand+variant) is **not** Pro-gated — showing the correct commands for a device is a correctness matter, not a customization perk, and matches how defaults already work for everyone today.
- 2026-08-20: **Build this goal first, before `goal-variant-remote-layout.md`, confirmed.** This work already touches every entry in `kRemoteLayoutItemDefinitions` (extending coverage to `youtube`/`input`) and is the natural point to fold `requiredCommandsForLayoutItemId`/`commandForLayoutItemId` into declarative fields on `RemoteLayoutItemDefinition` (OCP cleanup — see design review in `goal-variant-remote-layout.md` finding #4). The variant-layout goal then seeds its per-`(brand,variant)` catalogs from this goal's finished shape, avoiding rework.
- 2026-08-21: **Persist-on-change and reset-to-default already exist for positions and extend naturally** to `inDrawer`-flagged entries — no new save/load pathway, just one more field riding along with the values already flowing through it:
  - `RemoteLayoutEditor.onAcceptWithDetails` already calls `widget.onPersistLayout()` on every accepted drop (`remote_layout_editor.dart:167`) — auto-save per change, no separate save step; a drag-to-drawer persists the same entry with `inDrawer: true` and its `col`/`row` unchanged.
  - The editor header's `restart_alt` icon already wires to `_resetLayoutForActiveDevice()` → `_resetLayoutToDefaults()` → re-persists the cleared state (`remote_home_page.dart:1159-1167`, `1072-1081`); reset replaces the whole map with the default profile's real positions (`inDrawer: false` throughout), so no leftover drawer-parked entries survive a reset.

## Proposed UX design — drawer interaction (revised 2026-08-20 per user feedback)

Grounded directly in `remote_layout_editor.dart` and `remote_home_page.dart` (pencil icon = `Icons.edit_outlined` in `remote_home_app_bar_actions.dart:31` → `_toggleLayoutEditMode`, confirmed).

1. **Always visible during edit mode — no toggle icon, no open/close step.** The earlier icon-triggered-overlay proposal added a tap the user has to discover before they can even use the drawer. That protection wasn't actually needed: the "cancel edit" control (the pencil icon, `Icons.edit_outlined`) lives in the app bar (`remote_home_app_bar_actions.dart`), **outside** `RemoteLayoutEditor` entirely — there was never a collision to guard against. Instead, add the drawer as a **fixed, permanently-present region** in `RemoteLayoutEditor.build`'s existing `Column` (`remote_layout_editor.dart:283-318`) — e.g. a slim horizontally-scrollable strip between the header and the grid canvas. Because it's never toggled on/off during an edit session, `RemoteLayoutEditorGridGeometry.fitCellSize` computes the grid's available space once, consistently, for the whole session — "not intrusive to positioning" is satisfied by the drawer's presence being constant, not by a show/hide mechanic.
2. **Both remove and restore are drag, not tap.** Tap-to-restore was rejected earlier: the item would place itself automatically somewhere in the grid the user didn't choose, "confusing... you'll need to look for it." Drag keeps the destination visible and user-chosen, consistent with how repositioning already works.
   - **Remove (grid → drawer):** the drawer strip is a `DragTarget<String>` — the user drags a grid item (already `Draggable<String>`, no new widget needed) into it to park it (sets `inDrawer: true`, keeps `col`/`row` as-is, per Decisions above).
   - **Restore (drawer → grid):** drawer items are also `Draggable<String>` (reusing `RemoteLayoutEditorItemPreview` for feedback/preview, same as grid items) — the user drags one out onto a chosen grid cell. Grid cells' existing `DragTarget<String>` (`remote_layout_editor.dart:105-168`) already validates footprint/occupancy via `RemoteLayoutEditorDragSession`/`RemoteLayoutEditorGridGeometry` — no new validation logic needed, the drop just needs to also accept drags originating from the drawer, not only from other grid cells.
   - One interaction language throughout edit mode — drag between zones — no separate tap-badge gesture to learn.
3. Both directions call `onPersistLayout()` immediately, matching the existing auto-persist-on-change pattern. Empty-state text in the drawer ("Drag a command here to remove it from your remote") for discoverability.
4. Drawer items reuse `RemoteLayoutEditorItemPreview` (already used for grid items and drag feedback) — no new preview widget needed, visual consistency for free.
5. Items with `inDrawer: true` must be filtered out of the grid-canvas render path and routed to the drawer strip's render path instead — the one new bit of rendering logic this design needs.

## Open questions

None remaining for this goal — both prior questions resolved (see Decisions). Remaining dependency: `goal-variant-remote-layout.md`'s physical-remote source data determines each variant's actual default set.

## Relationship to `goal-variant-remote-layout.md`

Both features touch the same layout data model (`LayoutRepository`, `kRemoteLayoutItemDefinitions`, `buildFilteredRemoteLayoutItems`). Recommend deciding both designs together before implementing either, to avoid a rework where the per-variant-default work lands first and the drawer work then has to retrofit an excluded-items concept on top of it (or vice versa).

---
