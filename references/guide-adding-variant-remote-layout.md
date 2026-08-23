# Guide: Adding a Per-Brand-Variant Remote Layout

> ⚠️ **Status: mechanism fully wired, no real entries authored yet.** `RemoteLayoutDefaults`
> (`lib/remote_control/presentation/widgets/remote_layout_defaults.dart`) is live end-to-end:
> `_buildLayoutDefaultsForDevice` sources the item *list* from `layoutFor(device.brand,
> device.protocolVariant)` (`remote_home_page.dart`), and the rendering plumbing
> (`resolveItemDefinitionsById`, plus `imageIconSize`/`brandColor` on `LayoutEditItem`) is
> wired for both the live grid and the layout editor. `_map` itself is still empty — this
> guide's Step 4 is the only remaining work, per brand+variant. This guide documents the
> design agreed in `references/goals/goal-variant-remote-layout.md`; `goal-command-drawer.md`
> (referenced below) exists on the separate `feature/command-drawer` branch, not this one.
> Cross-check against the actual code before following this as a spec.

A per-brand-variant remote layout is an entry in `RemoteLayoutDefaults` that overrides the
app's default button grid for one specific `(TvBrand, protocolVariant)` pairing — used when
there's a real reason for that brand+variant's default arrangement to differ from the app's
baseline layout. That reason does **not** have to be strict parity with the physical remote
— the bar is whatever arrangement makes the most sense for that device in the app's own UI;
the physical remote is useful input when available, not a requirement to replicate exactly.
Most brand+variants will **never** need an override; the baseline covers them by default.

**Prerequisite:** the protocol variant itself must already exist — see
`references/guide-adding-protocol-variant.md`. This guide only covers giving an *already
resolvable* `(brand, variant)` its own layout; it does not create variants.

---

## How the system works

### The flow

`RemoteLayoutDefaults` (this guide) only ever computes a **default starting point**. It is
not the top of the resolution order — the user's own saved/customized layout, keyed by
`deviceId` and already implemented (`_loadLayoutForDevice`, `remote_home_page.dart:1083-1122`),
sits above it and wins whenever present. This guide only covers the default; it never
overrides an existing user customization.

```
pairing already resolved device.brand + device.protocolVariant
  (per guide-adding-protocol-variant.md — no new resolution logic here)

_loadLayoutForDevice(device):
  saved = isPro ? layoutRepository.loadLayout(device.id) : {}   // tier 0 — user's own customization

  defaults = _buildLayoutDefaultsForDevice(device)
    └─ RemoteLayoutDefaults.layoutFor(device.brand, device.protocolVariant)
         → _map[(brand, variant)]              // tier 1: exact variant override
         ?? _map[(brand, defaultVariant)]       // tier 2: brand's own default override
         ?? kRemoteLayoutItemDefinitions         // tier 3: existing global baseline
    └─ buildFilteredRemoteLayoutItems(supportedCommands, ...)  // capability filter, unchanged

  result = defaults, with `saved` positions overlaid on top wherever `saved` is non-empty
           // tier 0 always wins when present — tiers 1-3 only run to produce
           // what a fresh pairing (or non-Pro user) sees
```

`RemoteLayoutDefaults` itself only needs to hold **exceptions** — brand+variants with a real
reason to diverge from the baseline. A brand that never appears in the map always resolves
to tier 3 with zero extra code. This guide covers building tiers 1-3 only; tier 0 (the
save/customize/reset mechanics) already exists and needs no new work here.

### RemoteLayoutDefaults

**File:** `lib/remote_control/presentation/widgets/remote_layout_defaults.dart` — beside
`remote_layout_item_definitions.dart`, not `domain/models` (where `TvCapabilities` lives):
`RemoteLayoutItemDefinition` itself depends on Flutter types (`IconData`, `Color`) and
presentation-only assets, so putting `RemoteLayoutDefaults` in `domain/models` would make
domain code depend on presentation code.

```dart
class RemoteLayoutDefaults {
  const RemoteLayoutDefaults();

  static const Map<(TvBrand, String), List<RemoteLayoutItemDefinition>> _map = {
    // populated per Step 4 below — empty until the first override is added
  };

  List<RemoteLayoutItemDefinition> layoutFor(TvBrand brand, [String? variant]) {
    final v = variant ?? TvDevice.defaultProtocolVariant;
    return _map[(brand, v)] ??
        _map[(brand, TvDevice.defaultProtocolVariant)] ??
        kRemoteLayoutItemDefinitions;
  }
}
```

Instantiated inline at the call site (`const RemoteLayoutDefaults()`), same as
`const TvCapabilities()` is today (`tv_capabilities.dart:68`, called directly from
presentation code at `pairing_page_data.dart:79`) — no DI registration needed.

### When does an item actually show up?

Four independent gates, checked inside `buildFilteredRemoteLayoutItems`:

1. **Catalog membership.** Is the id present in `RemoteLayoutDefaults().layoutFor(device.brand,
   device.protocolVariant)` (or the global baseline, when no override applies)? An id absent from
   this list can never appear — nothing later can rescue it (see the caveat below).
2. **Command support.** For ids with a non-empty `commands` set, `supportedCommands.containsAll
   (definition.commands)` must hold, where `supportedCommands` comes from
   `commandService.supportedCommandsFor(device)` — independent of layout, this is "does this
   brand/adapter actually implement this command."
3. **`forceIncludeIds` bypasses gate 2, never gate 1.** A previously-saved item id skips the
   command-support check, so a device that stops reporting support for something the user already
   positioned doesn't just disappear — but it can't resurrect an id gate 1 already excluded.
4. **`searchInput` is the one exception** — it has no `commands`, so it's gated by
   `supportsTextInput` (`device.capabilities.contains(DeviceCapability.textInput)`) instead.

**Caveat, confirmed by real-device testing:** omitting an id from an override entry's item list
makes it vanish completely, not merely deprioritize it to the drawer. If a Pro user had already
positioned that id via their saved customization, `forceIncludeIds` cannot bring it back — the
id's definition is gone from the catalog being iterated, so there's nothing for gate 3 to check.
The saved position for that id becomes silently orphaned in `SharedPreferences`: never deleted,
never re-applied, never surfaced to the user. There's currently no way to express "not on by
default, but still available via the drawer" for an omitted id — only full inclusion or full
removal.

---

## Step-by-step: adding a new per-variant layout

The example below adds a hypothetical override for `Samsung Frame`
(`SamsungProtocolVariants.frameVariant`, per the example in
`guide-adding-protocol-variant.md`), giving it a dedicated **Art Mode** button where the
baseline has a generic Home button in that position — justified here by the real physical
remote having one, though that's an example input, not the only valid justification.

### Step 1 — Confirm the variant already exists

Verify the variant's constant, predicate, registry entry, and adapter are already in place
per `guide-adding-protocol-variant.md`'s checklist. This guide does not create variants.

### Step 2 — Confirm an override is actually needed

Compare the proposed arrangement to the app's current baseline
(`kRemoteLayoutItemDefinitions`, `remote_layout_item_definitions.dart:67-156`). Only proceed
if there's a real reason for this brand+variant to differ — matching its physical remote is
one valid reason, but so is "this arrangement is simply more usable for this device in the
app." If nothing justifies a difference, **do not add an entry** — let it resolve via tier 3.
An identical entry is pure duplication with no behavioral effect.

### Step 3 — Gather whatever reference informs the override

If physical-remote parity is the reason, determine what the real remote has: product manual,
manufacturer product photos, or a physical unit. If the reason is app-UX judgment instead,
document that reasoning just as clearly. Either way, note the justification in a comment next
to the entry (see Step 4) so a future maintainer knows *why* it exists — this has no other
authoritative home in the codebase.

### Step 4 — Build the item list

Reuse existing ids/icons/labels/footprints from `kRemoteLayoutItemDefinitionById` for any
button that matches the baseline; only override `col`/`row`/`width`/`height` for buttons
that are repositioned, and add new `RemoteLayoutItemDefinition` entries only for buttons the
baseline doesn't have at all.

**File:** `lib/remote_control/presentation/widgets/remote_layout_defaults.dart`

```dart
static const Map<(TvBrand, String), List<RemoteLayoutItemDefinition>> _map = {
  // ── Samsung Frame — source: Samsung Frame TV manual, 2026 model, p.12 ──────
  (TvBrand.samsung, SamsungProtocolVariants.frameVariant): [
    ...kRemoteLayoutItemDefinitions, // start from baseline, then adjust below
    // real remote replaces the generic 'home' slot with a dedicated Art Mode
    // button in the same position — override, don't duplicate the id
  ],
};
```

An entry may diverge an id on `icon`/`imageAsset`/`imageIconSize`/`brandColor` as well as
position — both the live grid and the layout editor resolve these from whichever
`RemoteLayoutItemDefinition` this entry provides for that id, not a fixed global one. (Before
the grid/editor rendering fix — see Design notes below — only `col`/`row`/`width`/`height`
overrides were safe to author; visual-identity overrides were silently ignored at render
time.)

Every id used must have a `commands`/`dispatchCommand` mapping — declarative fields on
`RemoteLayoutItemDefinition` (`remote_layout_item_definitions.dart`) — a new id with no
command mapping is inert.

### Step 5 — Register and verify fallback

Confirm the new entry only affects its exact `(brand, variant)` key — pairing a different,
unlisted variant of the same brand must still fall through to that brand's default-variant
entry (tier 2) or the global baseline (tier 3), not accidentally pick up this override.

### Step 6 — No separate drawer step

Commands the adapter supports but that don't appear in this entry's item list automatically
start in the drawer on a fresh pairing (per `goal-command-drawer.md`, on the separate
`feature/command-drawer` branch — not present on this branch yet: no entry for a command in
the positions map means it's not positioned, and the drawer is `supportedCommands` minus
positioned items) — no additional wiring needed here.

---

## Checklist

- [ ] Confirmed the protocol variant already exists per `guide-adding-protocol-variant.md` (constant, predicate, registry entry, adapter)
- [ ] Confirmed there's a real reason for this brand+variant to diverge from the baseline before adding an entry — no override added without one
- [ ] Documented that reason in a comment on the entry (physical remote reference, or app-UX rationale if that's the justification instead)
- [ ] Built the `List<RemoteLayoutItemDefinition>` entry, reusing existing ids/icons/labels/footprints where the button matches; new ids only where genuinely new
- [ ] Verified every id used has a `requiredCommands`/primary-command mapping
- [ ] Registered the entry in `RemoteLayoutDefaults._map` keyed by `(brand, variant)`
- [ ] Test: `layoutFor` resolves to this entry for the exact `(brand, variant)`
- [ ] Test: a different, unlisted variant of the same brand still falls through correctly (tier 2 or tier 3)
- [ ] Test: `_buildLayoutDefaultsForDevice` produces the new layout end-to-end for a device stamped with this variant
- [ ] Confirmed the default layout is visible to free-tier users too (not Pro-gated) — only editing/repositioning is Pro-gated

---

## Design notes

**Why does `RemoteLayoutDefaults` only hold exceptions, not every brand+variant?**
Per `goal-variant-remote-layout.md`'s DA-5 review: adding an entry has a real cost (research
or design judgment) and only pays off when there's an actual reason to diverge. Seeding
every key with a duplicate of the baseline was considered and rejected — it adds maintenance
surface with no behavioral difference.

**Why a three-tier fallback instead of `TvCapabilities`' two-tier pattern?**
`TvCapabilities._map` falls back to `{}` (empty) when nothing matches, which is fine for a
capability set — an empty set is a valid, meaningful answer. An empty *layout* is not a
useful answer — there'd be no remote to show. The third tier (`kRemoteLayoutItemDefinitions`)
gives every brand a guaranteed, working default, matching current behavior exactly for any
brand that never gets an override.

**Why is the default not Pro-gated, when the rest of layout customization is?**
Showing the correct commands for a user's specific device is a correctness property of the
core product, not a premium feature — matches how defaults already work today (they apply
to all users; only a *saved, customized* layout is Pro-gated). Only editing/repositioning —
including the command drawer, since moving an item is a position edit — is Pro-only.

**Why consider physical remotes at all, instead of just using capability filtering?**
Capability filtering (already built) answers "which commands does this device support." It
doesn't answer "where should that button be for this specific device." The per-variant
override exists to answer the second question — the physical remote is one useful signal
for that answer, not the only one; app-UX judgment is equally valid where it serves the user
better than replicating the physical unit.

**What happens if dozens of variants end up needing real overrides?**
`_map` is a single `static const` literal in this one file — fine at a handful of entries,
but each entry can hold a full `List<RemoteLayoutItemDefinition>` (heavier than
`TvCapabilities`'s `Set<DeviceCapability>` entries), so a few dozen real overrides would make
this file hard to scan. If that happens, split the data across per-brand files and merge them
with the const spread operator — `layoutFor()` and every caller stay unchanged, since nothing
outside this class ever reads `_map` directly:

```dart
// samsung_layout_overrides.dart
const Map<(TvBrand, String), List<RemoteLayoutItemDefinition>> samsungLayoutOverrides = {
  (TvBrand.samsung, SamsungProtocolVariants.frameVariant): [...],
};

// remote_layout_defaults.dart
static const Map<(TvBrand, String), List<RemoteLayoutItemDefinition>> _map = {
  ...samsungLayoutOverrides,
  ...lgLayoutOverrides,
};
```

Not worth building ahead of need — do this once the single-file map actually becomes hard to
read, not before.

---
