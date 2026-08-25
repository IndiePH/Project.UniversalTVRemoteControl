# Goal: Per-Brand-Variant Default Remote Layout

**Branch:** `feature/variant-remote-layout` (current)
**Status:** partially implemented — see "Implementation status" below (2026-08-22)
**Related:** `references/goals/goal-command-drawer.md` (same underlying data model — likely built together); `references/goals/goal-stable-device-identifier.md` (this goal's persisted state inherits that goal's `deviceId` fragility, not a blocker)
**Protocol variant guide:** `references/guide-protocol-variants.md` — 2026-08-25: the layout
override guide (`guide-adding-variant-remote-layout.md`, previously a separate companion doc
per the earlier design-review recommendation) was merged into this one as its "Adding a
variant remote layout" section, since it's the same `(TvBrand, String)`-keyed
variant-resolution shape, just for layout instead of adapter selection.
**Analysis session:** `references/goals/goal-command-drawer-and-variant-layouts.md`

> ⚠️ **This document has not been verified or approved by the user.** Every claim under
> "Verified facts" was confirmed by direct source reads (file:line cited) as of 2026-08-20,
> but the user has explicitly not yet checked this against their own understanding. Do not
> treat this as a spec. Everything under "Proposed design" is a recommendation only.

---

## Implementation status (2026-08-22)

The mechanism this goal describes is now built and tested on `feature/variant-remote-layout`:

- `RemoteLayoutDefaults` exists (`lib/remote_control/presentation/widgets/remote_layout_defaults.dart`
  — not `domain/models` as originally proposed below; see Design Review for why) with an empty
  `_map`. `layoutFor(brand, variant)` implements the tier 1→2→3 fallback exactly as decided.
- `_buildLayoutDefaultsForDevice` (`remote_home_page.dart`) now sources its item list from
  `RemoteLayoutDefaults().layoutFor(device.brand, device.protocolVariant)` instead of the global
  `kRemoteLayoutItemDefinitions`. `_loadLayoutForDevice` and `_resetLayoutToDefaults` both call
  this one function, so they can't drift apart from each other.
- A related rendering smell, found independently while wiring this in: the live grid and layout
  editor re-resolved each item's `imageAsset`/`imageIconSize`/`brandColor` from a single global
  id-keyed lookup at render time, ignoring whatever `RemoteLayoutDefaults` entry actually built
  the item. Fixed by carrying `imageIconSize`/`brandColor` on `LayoutEditItem` itself (grid) and
  by a variant-aware `resolveItemDefinitionsById(brand, variant)` (editor) — see
  `guide-protocol-variants.md`'s "Adding a variant remote layout" section for detail.
- Confirmed by real-device test (Android TV, `channel` filtered out of the default-variant entry):
  the override correctly excludes `channel` from the live grid, and reset respects it too.
- **A real gap found in testing, accepted as-is for now:** omitting an id from an override entry
  removes it entirely rather than just deprioritizing it to the drawer — a pre-existing saved
  customization positioning that id becomes silently orphaned (never re-applied, never surfaced).
  See `guide-protocol-variants.md`'s "When does an item actually show up?" subsection (under
  "Adding a variant remote layout").
- **Not yet done:** no real per-variant entry has been committed (only a local test entry); the
  regression tests Design Review finding #3 called for (`_buildLayoutDefaultsForDevice`/
  `buildFilteredRemoteLayoutItems`) still don't exist.

---

## Problem statement

Each adapter has its own command set and app-launch capability. The user wants each
brand-variant (or an adapter's default variant, when none applies) to get its own default
remote command/button layout immediately after pairing — unless the user already
customized their layout from a previous pairing of that device.

**Scope restated by user, 2026-08-20:** this goal focuses on (a) command mapping/available
commands per device, and (b) the deviceId's resolved default layout. Interpreted as: (a) is
already solved by the existing `supportedCommandsFor(device)` → adapter `supportedCommands`
resolution (verified fact #4 below) — no new "which commands exist" logic needed, only
consuming what already exists; the actual new work is (b), wiring `device.brand` +
`device.protocolVariant` (both already resolved and stored on `TvDevice` at pairing time)
into the new `RemoteLayoutDefaults` lookup so `_buildLayoutDefaultsForDevice` picks the
right default catalog for that device's `(brand, variant)` instead of the one global
catalog. *(Recorded as read — correct if a different split was intended.)*

## Verified facts (direct source reads, 2026-08-20)

### Variant → adapter resolution (already fully built, unrelated to layout)

1. `TvBrand` enum (`lib/remote_control/domain/models/tv_brand.dart`) = `{samsung, lg, hisense, androidTv, roku, tcl}`. **Correction to an earlier draft of this analysis:** Roku is its own top-level brand, not a TCL protocol variant, despite `TclRokuAdapter` living in a file named `tcl_roku_adapter.dart`. `TclRokuAdapter.brand => TvBrand.roku` (`tcl_roku_adapter.dart:49`).
2. Only `TvBrand.tcl` has more than one real protocol variant today: `TclGoogleTvAdapter` (variant `googleTv`, `tcl_google_tv_adapter.dart:31,34`) and `TclLegacyWifiAdapter` (variant `legacyWifi`, `tcl_legacy_wifi_adapter.dart:39,42`). Every other brand's `*_protocol_variants.dart` file was read in full this session and contains **only** a single `defaultVariant = TvDevice.defaultProtocolVariant` constant, no predicates, no branching: `android_tv/android_tv_protocol_variants.dart`, `samsung/samsung_protocol_variants.dart`, `hisense/hisense_protocol_variants.dart`, `lg/lg_protocol_variants.dart`.
3. `DefaultVariantResolutionRegistry._entries` (`lib/remote_control/data/variant_resolution_registry.dart:25-62`) resolves variant per `(brand, TvDeviceInfo)` at pairing time. Note: TCL's catch-all entry resolves unmatched TCL devices to `TclProtocolVariants.legacyWifi`, **not** `TvDevice.defaultProtocolVariant` (comment at line 51: "no default-variant adapter registered" for TCL) — TCL has no generic default adapter, only the two specific ones.
4. `BrandRoutedRemoteCommandService._adapterFor(brand, variant)` (`brand_routed_remote_command_service.dart:278-279`) does a `Map<(TvBrand, String), TvBrandAdapter>` lookup — this is the existing, complete mechanism for "which adapter/command-set applies to this paired device."
5. `TvCapabilities._map` (`lib/remote_control/domain/models/tv_capabilities.dart:20-54`) is a `Map<(TvBrand, String), Set<DeviceCapability>>` with fallback-to-brand-default (`capabilitiesFor`, lines 56-66) — **this is the existing precedent pattern** for "something keyed by (brand, variant) with graceful fallback," already proven out in this codebase for capabilities.

### Layout — currently brand/variant-agnostic (the actual gap)

6. `kRemoteLayoutItemDefinitions` (`remote_layout_item_definitions.dart:67-156`) is one single fixed catalog with fixed grid positions, used for every brand and variant. **No `(brand, variant)`-keyed layout selection exists anywhere** — confirmed by reading the full call chain from `remote_home_page.dart` down.
7. `_buildLayoutDefaultsForDevice` (`remote_home_page.dart:1124-1142`) computes defaults by calling `commandService.supportedCommandsFor(device)` (brand/variant-aware, via point 4 above) and filtering the one fixed catalog by it. So **item inclusion/exclusion already varies per adapter**; **arrangement (grid position) does not** — every brand gets the same positions for whatever items survive the filter.
8. Customization storage: `LayoutRepository.loadLayout`/`saveLayout` (`application/layout_repository.dart:3-9`, impl `data/shared_prefs_layout_repository.dart`) persist `Map<String, LayoutPosition>` keyed by `deviceId` under SharedPreferences key `remote_layout_v1_<deviceId>` (`shared_prefs_layout_repository.dart:8,15`). **Keyed by `deviceId`, not `(brand, variant)`.**
9. The actual current merge logic, read directly from `remote_home_page.dart:_loadLayoutForDevice` (1083-1122):
   ```
   saved = isPro ? layoutRepository.loadLayout(deviceId) : {}
   layoutItems = buildFilteredRemoteLayoutItems(
     supportedCommands: commandService.supportedCommandsFor(device),
     supportsTextInput: ...,
     forceIncludeIds: saved.keys,   // previously-placed items stay visible even if now unsupported
   )
   if (isPro) for each item: overlay saved[item.id].col/row if a valid placement exists
   ```
   This is **not** a clean `layout = isCustomized ? customized : default` ternary — it's "capability-filtered defaults, with previously-saved item ids force-kept, then positions overlaid from storage." "Is customized" is inferred only from `saved` being non-empty — no explicit flag exists.
10. The entire saved/customized-layout path is gated behind `proEntitlementService.isPro` (`remote_home_page.dart:1084-1087`) — non-Pro users always get computed defaults, never a saved customization, regardless of pairing history.

## Answering the user's specific question: where does DI / the ternary live?

Recommendation (not decided):

- **`LayoutRepository` stays `deviceId`-only** — do not add a `variant` parameter to `loadLayout`/`saveLayout`. `deviceId` already implies a fixed `(brand, protocolVariant)`, resolved and stored on `TvDevice` itself (per `guide-protocol-variants.md:1-7,211-213`). Re-deriving variant inside the repository would duplicate what's already resolved, contradicting the same reasoning the variant guide gives for why `TvCapabilities` does a direct map lookup instead of re-running predicates (`guide-protocol-variants.md:387-390`).
- **Add a new `(brand, variant)`-keyed default-layout source**, structurally a sibling of `TvCapabilities` — e.g. `RemoteLayoutDefaults` in `domain/models/`, same `Map<(TvBrand, String), ...>` + fallback-to-`defaultVariant` shape as `tv_capabilities.dart:20-61`.
- **Full resolution order, corrected (2026-08-20) — a 0th, higher-priority tier was missing:** the chain below (`_map[(brand,variant)] ?? _map[(brand, defaultVariant)] ?? kRemoteLayoutItemDefinitions`) only produces the *default starting point*. The user's own saved/customized layout — keyed by `deviceId`, Pro-gated, already implemented (`_loadLayoutForDevice`'s `saved` overlay, `remote_home_page.dart:1083-1122`, verified fact #9 above) — sits **above** all of it and wins whenever present:
  - **Tier 0 (highest — overrides everything below):** user's saved layout for this `deviceId`, if one exists and the user is Pro.
  - Tier 1: authored `RemoteLayoutDefaults` entry for the exact `(brand, variant)`.
  - Tier 2: authored `RemoteLayoutDefaults` entry for the brand's default variant.
  - Tier 3: existing global baseline catalog (`kRemoteLayoutItemDefinitions`), unchanged.
  - Tiers 1-3 only ever run when tier 0 is absent (fresh pairing, or non-Pro user) — they compute the *default*; tier 0 is a customization layered on top, not a peer in the same chain. "If no brand+variant layout supplied, use the default" refers to tiers 1→2→3; it was never meant to override an existing user customization.
- **The merge/ternary stays exactly where it already lives** — `remote_home_page.dart:_loadLayoutForDevice`/`_buildLayoutDefaultsForDevice`. Only one call changes: swap the single global `kRemoteLayoutItemDefinitions` source for the new `(device.brand, device.protocolVariant)`-aware default source. Everything else (saved-position overlay, `forceIncludeIds`, Pro gate) is unaffected.
- **DI impact: likely none.** If `RemoteLayoutDefaults` is a `const` class instantiated inline the way `TvCapabilities` is (`const TvCapabilities()` at call sites, `tv_capabilities.dart:68`), it needs no service-locator registration — just an import at the one changed call site. `LayoutRepository` DI registration is untouched.

## Decisions

- 2026-08-20: **Full replacement**, not a diff — matches the `TvCapabilities` precedent (`_map[(brand,v)] ?? _map[(brand,default)] ?? {}`, full set per key, never merged). Rationale (user): `capabilitiesFor`/this lookup is only ever called with a resolved device, so the fallback chain always resolves to a concrete key or the brand default — never a partial/empty result to merge against.
- 2026-08-20 (**revised** — corrects the seeding approach below): `RemoteLayoutDefaults` is `Map<(TvBrand, String variant), List<RemoteLayoutItemDefinition>>`, each item carrying its own grid position (`col`/`row`/`width`/`height`, matching fields `RemoteLayoutItemDefinition` already has). Matching `TvCapabilities`' own fallback pattern (`_map[(brand,v)] ?? _map[(brand,default)] ?? {}`): only add an explicit map entry for a `(brand, variant)` when there's a real reason for it to diverge from the baseline default; identical ones fall through to default with no redundant entry — per user: "have a default but allow per-variant override." ~~Every key seeded as a copy~~ was the wrong framing; superseded by this.
- 2026-08-20 (**revised** — loosens an earlier overstatement): the justification for a per-variant entry is **not** required to be strict physical-remote parity. A brand+variant's real physical remote is one legitimate *input* to what its default should look like, but the actual bar is whatever arrangement makes the most sense for that device in the app's own UI — which may match the physical remote, may improve on it, or may ignore it entirely if the app-native arrangement serves the user better. Per user: "it doesn't really need to be the exact remote... it's possible the UI just makes more sense than the remote." This replaces the earlier "source of truth = physical remote" framing.
  - **Prerequisite softened accordingly:** sourcing physical remote references (manuals, product photos, physical units) is *useful input*, not a hard blocker — a per-variant entry can be justified by app-UX reasoning alone. Doesn't block starting either way — the baseline default works until any entry is authored.
- 2026-08-20 (**corrected**): the per-`(brand,variant)` **default** command set applies to **all users, free included** — showing the correct commands for a device is a correctness matter, not customization, and matches how defaults already work for everyone today (`_loadLayoutForDevice`: defaults apply to all; only the *saved override* is Pro-gated, `remote_home_page.dart:1084-1087`). Only **editing/repositioning** (including the command drawer's drag-in/drag-out, since that's a position edit) is Pro-only. The earlier "both features Pro-gated" note was wrong for the default part — corrected here and in `goal-command-drawer.md`.
- 2026-08-20: **Sequencing — command drawer first, then this goal.** The drawer work already needs to touch every `kRemoteLayoutItemDefinitions` entry (extend coverage to `youtube`/`input`; see Design Review finding #4 below re: folding the id-based switches into declarative fields). This goal's per-`(brand,variant)` seeding should copy the *finished* shape once, rather than being built against the old switch-based shape and reworked later.

## Open questions (remaining)

None on design — resolved (see Decisions: app-UX appropriateness, optionally informed by the physical remote, is the concrete justification for per-variant positions — not strict parity). No hard prerequisite remains; physical remote references are useful input when available, not a blocker.

## Design Review (clean-code-solid / design-pattern-selection / refactoring / architecture-consistency / abstraction-domain-modeling)

Findings from a follow-up review pass (2026-08-20), each grounded in cited source reads or the codebase's own established conventions. Recommendations only — nothing here is implemented.

1. **Design-pattern-selection — full-replacement is the established convention, now confirmed as the decision** (see Decisions above). `TvCapabilities._map` is the only other `(brand, variant)`-keyed lookup in the codebase, and it's full-replacement-with-fallback, never a merge.
2. **DA-5 (avoid overengineering) — resolved.** Concrete justification for per-variant *position* differences (not just inclusion): whatever arrangement makes the most sense for that brand+variant in the app's own UI — informed by, but not bound to replicate, that device's real physical remote. Not overengineering — real, stated business requirement, just not a strict-parity one.
3. **Refactoring — verify test coverage on `_buildLayoutDefaultsForDevice`/`_loadLayoutForDevice` (`remote_home_page.dart`) before extending them.** The refactoring skill's precondition (adequate coverage before structural change) hasn't been explicitly confirmed for these two methods specifically, even though adjacent layout tests exist (`remote_layout_drop_resolver_test.dart`, `shared_prefs_layout_repository_test.dart`, etc., per `changelog.md` 2026-05-22 entry).
4. **Clean-code-solid / OCP — `requiredCommandsForLayoutItemId`/`commandForLayoutItemId` (`remote_layout_item_definitions.dart:170-209`) are switch statements over item-id strings.** Adding a new layout item (e.g. `youtube`, planned in `goal-command-drawer.md`) means editing a switch — an OCP smell (extension requires modification). Since the drawer work already touches every entry, that's the opportune moment to move `requiredCommands`/`primaryCommand` onto `RemoteLayoutItemDefinition` as declarative fields instead — see sequencing decision above.
5. **Abstraction-domain-modeling — `RemoteLayoutDefaults` is a legitimate domain concept but creates an undocumented maintenance coupling to `guide-protocol-variants.md`.** That guide's checklist doesn't know this class will exist; recommend adding a step to it (mirroring its existing optional "Capability override" step) once implemented, so new variants don't silently miss a layout entry. **Resolved 2026-08-25:** the coupling is now moot — the layout guide was merged into `guide-protocol-variants.md` as its "Adding a variant remote layout" section, in the same file rather than a separate one that could drift out of sync.
6. **Architecture-consistency — confirmed CONSISTENT, not a new precedent.** Verified `TvCapabilities` is already instantiated directly from presentation-layer code (`pairing_page_data.dart:79`), not only from `data`/`domain` — so calling a new `domain/models` lookup directly from `remote_home_page.dart` matches an existing pattern rather than introducing one.

correctness-validation / TQ-1 / MF-1 (test coverage, no-behavior-change, regression) aren't triggered yet — no code has changed; this remains a planning document.

## Relationship to `goal-command-drawer.md`

Both features share the same data model surface (`LayoutRepository`, `kRemoteLayoutItemDefinitions`, `buildFilteredRemoteLayoutItems`, the `_loadLayoutForDevice` merge). A per-variant default layout and a drawer for excluded-but-valid commands are two views of the same underlying "what's shown vs. what's available" question — recommend designing them together.

---
