# Guide: Protocol Variants

A protocol variant is a string tag on `TvDevice.protocolVariant` that tells
`BrandRoutedRemoteCommandService` which adapter to select, and tells that adapter which
behavioral path to take, for a specific device/model. It can be set as early as discovery
time and is only ever *refined*, never reset, at pairing time — once resolved it's
persisted, so every subsequent command dispatch already knows which path to use without
re-deriving anything.

## Contents

- [Where a protocol variant is determined](#where-a-protocol-variant-is-determined)
- [Where a protocol variant is applied](#where-a-protocol-variant-is-applied)
- [Why three separate mechanisms, not one](#why-three-separate-mechanisms-not-one)
- [Adding a new behavioral variant (step-by-step)](#adding-a-new-behavioral-variant-step-by-step)
- [Adding Behavioral Variant Checklist](#adding-behavioral-variant-checklist)
- [Adding Behavioral Variant Design notes](#adding-behavioral-variant-design-notes)
- [Adding a variant remote layout](#adding-a-variant-remote-layout)

---

## Where a protocol variant is determined

There are three moments a variant can be resolved, each with its own interface, because
each one has access to different information and none of them can substitute for another:

| # | Moment | Mechanism | Status |
|---|---|---|---|
| 1 | Discovery time | `DiscoveryVariantResolutionRegistry` | implemented |
| 2 | Pairing time | `VariantResolutionRegistry` | implemented |
| 3 | Manual add (by IP) | `ManualAddVariantProbe` | implemented |

### 1. Discovery time (structural) — `DiscoveryVariantResolutionRegistry`

**Status: implemented.** **File:**
`lib/remote_control/data/discovery_variant_resolution_registry.dart`

Resolves which transport/adapter a device needs, **before any adapter has made contact** —
called from each scanner (`SsdpDeviceDiscoveryService`, `MdnsDeviceDiscoveryService`,
`RokuSsdpDiscoveryService`) at the exact moment it constructs a `TvDevice`. It's keyed by
`(TvBrand, DiscoverySource?)`, where `DiscoverySource` (`ssdp` / `mdns` / `roku`) records
which scanner found the device — a free signal, since each scanner class only ever emits
devices speaking the one protocol it scans for (the SSDP scanner only finds SSDP-speaking
devices, the mDNS scanner only finds `androidtvremote2`'s mDNS service, etc.).

```dart
abstract interface class DiscoveryVariantResolutionRegistry {
  String resolveFromDiscovery({required TvBrand brand, required DiscoverySource? source});
}
```

Unlike the behavioral resolver below, this returns a **non-nullable** `String` — it applies
its own `?? TvDevice.defaultProtocolVariant` fallback internally (`_discoveryEntries[(brand,
source)] ?? TvDevice.defaultProtocolVariant`), since at discovery time there is no earlier
variant to preserve; the default is the only sensible fallback. Sync, zero I/O — a plain
`Map<(TvBrand, DiscoverySource?), String>` lookup, no predicates.

### 2. Pairing time (behavioral) — `VariantResolutionRegistry`

**Status: implemented.** **File:** `lib/remote_control/data/variant_resolution_registry.dart`

```
preparePairing()
  └─ adapter.queryDeviceInfo()          → TvDeviceInfo? (model, firmware)
  └─ variantRegistry.resolve()          → String? (variant tag, or null = no info-based rule for this brand)
  └─ resolved ?? device.protocolVariant → String (never clobbers a variant already set before pairing)
  └─ TvCapabilities().capabilitiesFor() → Set<DeviceCapability>
  └─ device.copyWith(protocolVariant: ..., capabilities: ...) → stored / returned
```

Refines the variant **after** an adapter has already made contact and probed the TV — a
dialect choice *within* an already-fixed transport (e.g. a firmware-specific quirk), not a
choice of transport itself. That choice was already made by mechanism #1 (or by the default,
for manually-added/non-discovered devices) before this ever runs.

```dart
class _VariantResolutionEntry {
  final bool Function(TvDeviceInfo info) matches; // ← the predicate
  final String variant;
}
```

Entries are grouped by brand: `_entriesByBrand` is a `Map<TvBrand, List<_VariantResolutionEntry>>`
(no `brand` field on the entry itself — the map key already carries it). `resolve()` returns
`null` if `info` is null, `null` if the brand has no entry in the map at all, otherwise walks
that brand's list in order and returns the **first** entry where `entry.matches(info)` is
true — or `null` if none match. **Most brands have no entry at all today** — that's the
correct, common case ("no opinion"; see the design notes below), not a gap to fill in. The
caller (`BrandRoutedRemoteCommandService.preparePairing`) applies `resolve(...) ??
device.protocolVariant`, so "no info-based rule for this brand" safely keeps whatever variant
the device already had instead of resetting it.

After pairing, `TvDevice.protocolVariant` is available on every call to `sendCommand`,
`sendText`, etc., so adapters can branch on it without re-querying the TV.

### 3. Manual add, by IP (structural) — `ManualAddVariantProbe`

**Status: implemented.** **File:** `lib/remote_control/data/manual_add_variant_probe.dart`.
See `references/goals/goal-sony-adapter.md`'s Decisions log ("B2 recommendation #3
superseded" entry) for the full design trail.

When a device is added by typing a brand + IP directly, no scanner ever ran — there is no
`DiscoverySource` to look up (mechanism #1 doesn't apply), and no adapter has probed the TV
yet either (mechanism #2 doesn't apply). Neither existing resolver has anything to key off.
The fix: probe each of the brand's known variants directly. Every `TvBrandAdapter` already
implements a safe, side-effect-free `probeConnection` (raw TCP connect + close, no protocol
handshake, no pairing/PIN ever triggered — see `android_tv_tcp_transport_client.dart`'s
`probe()`, already relied on in production by `AdapterTvReachabilityService`), so the first
candidate variant whose adapter is reachable wins, with `?? TvDevice.defaultProtocolVariant`
if none respond:

```dart
abstract interface class ManualAddVariantProbe {
  Future<String> resolve({required TvBrand brand, required String host});
}
```

`DefaultManualAddVariantProbe` derives candidates from the DI-built `List<TvBrandAdapter>`
(already the source of truth for "which variants exist" — see "Why three separate
mechanisms, not one" below), not a new static table. It short-circuits to the single known
variant with zero I/O for every brand except Sony (today's only brand with two live
variants), and probes in an explicit private try-order (`_variantTryOrder` — Google TV path
before Bravia) since `DiscoveredDeviceSupport.brandIdentificationPriority` can't order
between one brand's own variants (it's keyed by `TvBrand` only).

Wired into `pairing_page.dart`'s `_addManualDevice` as an **optional** field on
`PairingPage` (`manualAddVariantProbe`), not a required one — making it required would have
broken every test constructing `PairingPage` directly. When the probe *is* provided (always
true in production), TCL needs no special case at the call site: the probe's own
single-candidate short-circuit already resolves it to `legacyWifi` (confirmed only one TCL
adapter, `TclLegacyWifiAdapter`, is actually registered in DI — `TclRokuAdapter` reports
`TvBrand.roku`, not `TvBrand.tcl`). When the probe is `null` (test convenience only), a
bare `TvDevice.defaultProtocolVariant` fallback would silently reintroduce the exact bug
the original hardcoded ternary existed to prevent — `_adapterFor` does a direct,
no-fallback `(brand, variant)` map lookup, and `'default'` doesn't match what
`TclLegacyWifiAdapter` actually reports, so a manually-added TCL device would resolve to no
adapter at all. `_fallbackVariantWithoutProbe` (`pairing_page.dart`) keeps this one
brand-specific case for exactly that reason — every other brand's default adapter already
uses `TvDevice.defaultProtocolVariant` itself, so no other case is needed.

---

## Where a protocol variant is applied

Once resolved, `device.protocolVariant` is read at every one of these call sites — none of
them re-derive or re-resolve it:

- `BrandRoutedRemoteCommandService._adapterFor(brand, variant)` — the single lookup every
  method on the service goes through: `unpairDevice`, `cancelPairing`, `connect`,
  `preparePairing`, `submitPairingCode`, `sendCommand`, `sendText`, `supportedCommandsFor`,
  `watchRemoteTextInputReady`, `checkRemoteTextInputReady`, `watchConnectionState`,
  `queryDeviceInfo`, `readerForDevice` (`brand_routed_remote_command_service.dart`).
- `TvCapabilities().capabilitiesFor(brand, [variant])` — capability set lookup,
  `(brand, variant)`-keyed (`tv_capabilities.dart:62`).
- `TvCapabilities().pinFormatFor(brand, [variant])` — PIN format for the pairing dialog
  (`tv_capabilities.dart:74`).
- `PairingProgressHintRegistry.hintFor(brand, variant)` — pairing-progress copy shown to the
  user while pairing (`pairing_progress_hint_registry.dart`, called from `pairing_page.dart`).
- `RemoteLayoutDefaults.layoutFor(brand, variant)` — the default remote button grid for a
  `(brand, variant)` pairing, used only as a starting point beneath the user's own saved
  layout (`remote_layout_defaults.dart`, called from `remote_home_page.dart`). See
  "Adding a variant remote layout" below for how to add an override — it treats variant
  resolution as an already-solved prerequisite, not something it redoes.

All five are `(TvBrand, String)`-keyed lookups against data that's already fixed by the time
they run — none of them re-run predicates or re-probe anything.

---

## Why three separate mechanisms, not one

It's tempting to want a single `resolve(...)` that "just knows" the variant. It can't, and
merging the three would violate the same principles that justify keeping them apart:

| Resolver | When | Input | Mechanism |
|---|---|---|---|
| `DiscoveryVariantResolutionRegistry` | discovery scan time, pre-first-contact | `(TvBrand, DiscoverySource?)` | sync map lookup, zero I/O |
| `VariantResolutionRegistry` | pairing time, post-first-contact | `(TvBrand, TvDeviceInfo?)` | sync predicate match against already-fetched data |
| `ManualAddVariantProbe` | manual-add time, pre-first-contact | `(TvBrand, host)` | async, does its own network I/O per candidate |

Each has a genuinely different input, timing, and mechanism — not an accidental
duplication. Discovery-time resolution can only use `DiscoverySource`, because
`TvDeviceInfo` doesn't exist yet — nothing has probed the TV. Behavioral resolution can
only use `TvDeviceInfo`, because that's the only thing a live probe produces, and by then
an adapter (and therefore a transport) has already been chosen — a `DiscoverySource` would
be stale information at that point even if it were available. Manual-add has neither
signal at all, since no scanner ran, so it substitutes active per-candidate probing for the
free signal the other two rely on.

A single merged interface would force every caller to depend on parameters and code paths
it never uses (interface segregation violation) and give the merged class three unrelated
reasons to change — a new discovery-source mapping, a new info-based dialect rule, and a
probe-timeout tweak are orthogonal concerns (single-responsibility violation).

What doesn't need three copies: the catalog of "which variants exist for a brand." That
fact is already single-sourced by the DI-built `List<TvBrandAdapter>`
(`remote_control_di_config.dart`) — every real variant requires an adapter to do anything at
all, so an adapter's `(brand, protocolVariant)` pair already declares that the variant
exists. `BrandRoutedRemoteCommandService` already builds its dispatch map straight from that
list; `ManualAddVariantProbe` filters that exact same list rather than introducing a second
one that could drift out of sync. Discovery does **not** need this list at all —
none of the three scanners nor `CompositeDeviceDiscoveryService` take any adapter dependency,
since discovery-time resolution only has to answer "what string goes into `protocolVariant`,"
a pure lookup that never needed the adapter's actual behavior.

One caution: `DiscoveredDeviceSupport.brandIdentificationPriority` (used to dedupe when
multiple scanners report the same host) is keyed by `TvBrand` only — it orders *different
brands* colliding on one host, and cannot order *between a single brand's own variants*. Do
not reach for it to decide try-order inside `ManualAddVariantProbe`; that ordering doesn't
exist anywhere yet and needs its own small, explicit answer when that mechanism is built.

---

## Adding a new behavioral variant (step-by-step)

This walks through adding a new **pairing-time (behavioral)** variant via
`VariantResolutionRegistry` — mechanism #2 above. Adding a variant that also needs its own
discovery-time entry (mechanism #1) or manual-add candidate (mechanism #3) needs those
mechanisms' own wiring too; this section doesn't cover that yet since only mechanism #2 has
enough real precedent (TCL, Samsung-hypothetical below) to generalize from.

The example below adds a hypothetical `Samsung Frame` variant that uses a different
power-toggle command path.

### Step 1 — Declare the variant constant and predicate

Add a new constant **and a matching predicate** to the brand's `*ProtocolVariants` class.
The predicate is used by `VariantResolutionRegistry` to detect the variant from device
info at pairing time.

**File:** `lib/remote_control/data/adapters/samsung/samsung_protocol_variants.dart`

```dart
abstract final class SamsungProtocolVariants {
  static const String defaultVariant = TvDevice.defaultProtocolVariant;
  static const String frameVariant = 'samsung_frame'; // ← add constant

  // ← add predicate alongside its constant
  static bool isFrameSeries(TvDeviceInfo info) {
    final model = info.modelIdentifier ?? '';
    return model.startsWith('QM') || model.startsWith('LS');
  }
}
```

Use a unique, lowercase, underscore-separated string for the constant. It is persisted
to `SharedPreferences` as-is (via `TvDevice.toJson`), so treat it as a stable identifier
— never rename it once shipped.

### Step 2 — Register the matching rule

Add a new `_VariantResolutionEntry` to the brand's list in `_entriesByBrand` — a brand
with no existing list yet needs a new map entry; a brand that already has one just gets
a new list item, **before** any existing catch-all for that brand.

**File:** `lib/remote_control/data/variant_resolution_registry.dart`

```dart
static final Map<TvBrand, List<_VariantResolutionEntry>> _entriesByBrand = {
  // ── Samsung ──────────────────────────────────────────────────────────────
  TvBrand.samsung: [
    _VariantResolutionEntry(              // ← specific rule, checked first
      matches: SamsungProtocolVariants.isFrameSeries, // ← predicate
      variant: SamsungProtocolVariants.frameVariant,
    ),
  ],
  // ── TCL (existing, kept as reference for the catch-all shape) ────────────
  TvBrand.tcl: [
    _VariantResolutionEntry(
      matches: TclProtocolVariants.isLegacyWifi,
      variant: TclProtocolVariants.legacyWifi,
    ),
    _VariantResolutionEntry(matches: (_) => true, variant: TclProtocolVariants.legacyWifi),
  ],
  // ...
};
```

**`matches` receives a `TvDeviceInfo`** populated by `adapter.queryDeviceInfo()`. The
available fields are:

| Field              | Source                       | Notes                              |
|--------------------|------------------------------|------------------------------------|
| `modelIdentifier`  | `queryDeviceInfo` → adapter  | Null if the brand doesn't probe    |
| `firmwareVersion`  | `queryDeviceInfo` → adapter  | Null if the brand doesn't probe    |

If `info` itself is null (brand returned nothing from `queryDeviceInfo`), or the brand has
no list in `_entriesByBrand`, or nothing in its list matches, `resolve()` returns `null` —
**not** `TvDevice.defaultProtocolVariant`. The caller (`BrandRoutedRemoteCommandService
.preparePairing`) is what applies the fallback: `resolve(...) ?? device.protocolVariant`.
This matters — it means "no info-based rule for this brand" safely keeps whatever variant
the device already had (e.g. one a discovery-time resolver already set), instead of
resetting it back to the default. **Do not add a catch-all `(_) => true` entry just to
return the default** — omitting the brand from `_entriesByBrand` entirely already produces
that fallback via the caller's `??`, with less code (TCL's catch-all is a real exception:
it's needed because TCL's *default* protocol variant has no adapter registered for it, so
"no opinion" would leave `device.protocolVariant` pointing at an adapter that doesn't
exist — see the design notes below).
**Adapters that don't currently probe device info should return `TvDeviceInfo()` (empty,
non-null) rather than `null`.** An empty `TvDeviceInfo` lets the entry list run — any
non-catch-all rules just won't match yet — but specific model rules become reachable as
soon as the transport starts providing data.

### Step 3 — Create a variant-specific adapter

Each protocol variant gets its own adapter class. The adapter is not aware of other
variants; it simply implements the protocol for its one variant. The router selects the
right adapter by matching both brand and variant, so no branching inside an adapter is
ever needed.

**Create:** `lib/remote_control/data/adapters/samsung_frame_adapter.dart`

```dart
class SamsungFrameAdapter implements TvBrandAdapter {
  SamsungFrameAdapter({required SamsungTransportClient transportClient})
      : _transportClient = transportClient;

  @override
  TvBrand get brand => TvBrand.samsung;

  @override
  String get protocolVariant => SamsungProtocolVariants.frameVariant;

  // ... implement sendCommand, sendText, etc. for the Frame protocol

  final SamsungTransportClient _transportClient;
}
```

**Register it in DI** alongside the existing default adapter:

```dart
// remote_control_di_config.dart
final adapters = [
  SamsungAdapter(transportClient: sl<SamsungTransportClient>()),      // default
  SamsungFrameAdapter(transportClient: sl<SamsungTransportClient>()), // ← new
  LgAdapter(transportClient: sl<LgTransportClient>()),
  HisenseAdapter(transportClient: sl<HisenseTransportClient>()),
  // ... every other brand's adapter(s) stay listed here too
];
final commandService = BrandRoutedRemoteCommandService(
  adapters: adapters,
  variantRegistry: sl<VariantResolutionRegistry>(),
  localizedStrings: sl<LocalizedStrings>(),   // required
  identityRegistry: sl<DeviceIdentityRegistry>(), // optional, but wired everywhere it's registered
);
```

### Step 4 — Capability override (only if needed)

If the new variant also changes which capabilities the device has, add a new entry to
`TvCapabilities._map` keyed on `(brand, variantConstant)`. Place it before the brand's
default-variant entry so it is unambiguous which entry applies to which variant.

**File:** `lib/remote_control/domain/models/tv_capabilities.dart`

```dart
static const Map<(TvBrand, String), Set<DeviceCapability>> _map = {
  // ── Samsung Frame ─────────────────────────────────────────────────────────
  (TvBrand.samsung, SamsungProtocolVariants.frameVariant): {
    DeviceCapability.keyCommands,
    DeviceCapability.powerControl,           // no textInput on Frame series
  },
  // ── Samsung (default) ─────────────────────────────────────────────────────
  (TvBrand.samsung, TvDevice.defaultProtocolVariant): {
    DeviceCapability.keyCommands,
    if (_samsungTextInputEnabled) DeviceCapability.textInput,
    DeviceCapability.powerControl,
  },
  // ── LG ────────────────────────────────────────────────────────────────────
  (TvBrand.lg, TvDevice.defaultProtocolVariant): { ... },
  // ── Hisense ───────────────────────────────────────────────────────────────
  (TvBrand.hisense, TvDevice.defaultProtocolVariant): { ... },
};
```

Capabilities are looked up by `(brand, resolvedVariant)` after pairing. If a variant has
no entry in `_map`, `capabilitiesFor` falls back to the brand's default-variant entry
automatically — so omitting this step is safe when capabilities don't differ.

Avoid this step unless capabilities genuinely differ — the variant tag is the right
place for behavioral branching, not the capability set.

---

## Adding Behavioral Variant Checklist

- [ ] Variant constant added to `*ProtocolVariants`
- [ ] Predicate added to `*ProtocolVariants` alongside the constant
- [ ] Entry added in `DefaultVariantResolutionRegistry._entriesByBrand`'s list for the brand, before any existing catch-all for that brand
- [ ] `queryDeviceInfo` returns `TvDeviceInfo` with a populated `modelIdentifier` (or `firmwareVersion`) for the matching device
- [ ] Variant-specific adapter class created, `protocolVariant` getter returns the new constant
- [ ] Adapter registered in DI config alongside the existing default adapter
- [ ] Capability override added to `TvCapabilities._map` (only if capabilities differ from brand default)
- [ ] Test: registry resolves the correct variant for a matching `TvDeviceInfo`
- [ ] Test: registry returns `null` for a non-matching `TvDeviceInfo` (not the string `default` — see the design notes on why `resolve()` is nullable)
- [ ] Test: adapter produces the correct transport command for the new variant

---

## Adding Behavioral Variant Design notes

**Why a string and not an enum?**  
Variants are stored in `SharedPreferences`. A string is stable across renames and can
survive devices that were paired on an older build that predates the enum value. Adding
a new string constant is backwards-compatible; adding a new enum value to a serialized
enum is not.

**Why the registry over in-adapter detection?**  
Pairing happens once; commands happen constantly. Detecting the model in `sendCommand`
on every call would require caching or re-querying. The registry stamps the result once
at pairing time so the adapter receives a pre-resolved `device.protocolVariant` on every
subsequent call with zero extra I/O.

**Why does the predicate live in `*ProtocolVariants` and not on the adapter?**  
An adapter's responsibility is communicating with the TV. "Is this device in my variant?"
is a selection concern — it belongs with the thing being selected (the variant constant),
not the thing doing the work (the adapter). Putting it on the adapter would also create a
dependency from the registry down into the adapter layer, reversing the correct flow
(registry selects adapter, so registry must not depend on adapter).

**Why does `TvCapabilities` use a map keyed on `(brand, variant)` instead of predicates?**  
By the time capabilities are looked up, the variant string is already resolved. Re-running
predicates against `TvDeviceInfo` a second time would duplicate detection logic. The map
lookup is a direct O(1) read — no predicate, no iteration, no duplication.

**Why does `resolve()` return `String?` instead of a guaranteed `String`?**  
Returning `null` for "no info-based rule for this brand" is an honest optional, distinct
from "explicitly resolved to the default variant." The alternative — always returning a
string, using `TvDevice.defaultProtocolVariant` to mean both "explicitly default" and
"nothing matched" — was tried and rejected: it overloads a real domain constant to also
mean "no opinion," which a future brand needing those two cases to differ would hit with
no compiler warning. The caller (`preparePairing`) applies `?? device.protocolVariant`,
so "no rule matched" safely preserves whatever variant the device already had (e.g. one a
discovery-time resolver already set) instead of resetting it.

**Why does TCL keep a catch-all entry when most brands have none?**  
Most brands need no entry at all — "no opinion" already falls back correctly to
`device.protocolVariant` at the call site. TCL is the one exception: no adapter is
registered for `(TvBrand.tcl, TvDevice.defaultProtocolVariant)` in DI (only
`TclRokuAdapter` and `TclLegacyWifiAdapter` exist), so if TCL fell through to "no opinion,"
the fallback would point at a variant with no adapter behind it at all. TCL's catch-all
entry exists to guarantee a real, adapter-backed variant is always returned — it is a
genuine exception, not a template to copy for other brands.

**Why doesn't discovery-time resolution need the adapter list, but manual-add will?**  
Discovery-time resolution (#1) only answers "what string goes into `protocolVariant`" from
a signal (`DiscoverySource`) that already tells it which protocol is in play — no probing
needed, so no adapter dependency needed either. Manual-add (#3) has no such signal, so it
has nothing to look up *from* — it has to ask the candidates directly, which means it needs
the actual adapters (specifically their `probeConnection`) to ask.


---

---

## Adding a variant remote layout

A per-brand-variant remote layout is an entry in `RemoteLayoutDefaults` that overrides the
app's default button grid for one specific `(TvBrand, protocolVariant)` pairing — used when
there's a real reason for that brand+variant's default arrangement to differ from the app's
baseline layout. That reason does **not** have to be strict parity with the physical remote —
the bar is whatever arrangement makes the most sense for that device in the app's own UI; the
physical remote is useful input when available, not a requirement to replicate exactly. Most
brand+variants will **never** need an override; the baseline covers them by default.

**Prerequisite:** the protocol variant itself must already exist — see "Adding a new
behavioral variant" above. This section only covers giving an already-resolvable `(brand,
variant)` its own layout; it does not create variants.

> **Status: mechanism fully wired, no real entries authored yet.** `RemoteLayoutDefaults`
> (`lib/remote_control/presentation/widgets/remote_layout_defaults.dart`) is live end-to-end:
> `_buildLayoutDefaultsForDevice` sources the item *list* from `layoutFor(device.brand,
> device.protocolVariant)` (`remote_home_page.dart`), and the rendering plumbing
> (`resolveItemDefinitionsById`, plus `imageIconSize`/`brandColor` on `LayoutEditItem`) is
> wired for both the live grid and the layout editor. `_map` itself is empty by design, not by
> gap — most brand+variants never need an override; the step-by-step below only applies to the
> ones that do. The command drawer (`LayoutZone.grid`/`LayoutZone.drawer`) is also live on this
> branch, not a future dependency — see Step 6 below.

### How the layout-default system works

`RemoteLayoutDefaults` only ever computes a **default starting point**. It is not the top of
the resolution order — the user's own saved/customized layout, keyed by `deviceId` and already
implemented (`_loadLayoutForDevice`, `remote_home_page.dart:1100-1124`), sits above it and wins
whenever present. This section only covers the default; it never overrides an existing user
customization.

```
device.brand + device.protocolVariant already resolved
  (see "Where a protocol variant is determined" above — no new resolution logic here)

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
to tier 3 with zero extra code.

**File:** `lib/remote_control/presentation/widgets/remote_layout_defaults.dart` — beside
`remote_layout_item_definitions.dart`, not `domain/models` (where `TvCapabilities` lives):
`RemoteLayoutItemDefinition` itself depends on Flutter types (`IconData`, `Color`) and
presentation-only assets, so putting `RemoteLayoutDefaults` in `domain/models` would make
domain code depend on presentation code.

```dart
class RemoteLayoutDefaults {
  const RemoteLayoutDefaults();

  static final Map<(TvBrand, String), List<RemoteLayoutItemDefinition>> _map = {
    // populated per the step-by-step below — empty until the first override is added
  };

  List<RemoteLayoutItemDefinition> layoutFor(TvBrand brand, [String? variant]) {
    final v = variant ?? TvDevice.defaultProtocolVariant;
    return _map[(brand, v)] ??
        _map[(brand, TvDevice.defaultProtocolVariant)] ??
        kRemoteLayoutItemDefinitions;
  }
}
```

Note: `_map` is `static final`, not `static const` — a `List<RemoteLayoutItemDefinition>`
entry generally isn't const-constructible (unlike `TvCapabilities._map`'s `Set<DeviceCapability>`
entries), so don't copy the `const` keyword into a new entry without checking it compiles.

Instantiated inline at the call site (`const RemoteLayoutDefaults()`), same as
`const TvCapabilities()` is today (const constructor at `tv_capabilities.dart:13`, called
directly from presentation code at `pairing_page_data.dart:154`, and from half a dozen other
call sites across `data/` — e.g. `brand_routed_remote_command_service.dart:85`) — no DI
registration needed.

#### When does an item actually show up?

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

### Adding a variant remote layout (step-by-step)

The example below adds a hypothetical override for `Samsung Frame`
(`SamsungProtocolVariants.frameVariant`, per the example above), giving it a dedicated **Art
Mode** button where the baseline has a generic Home button in that position — justified here by
the real physical remote having one, though that's an example input, not the only valid
justification.

#### Step 1 — Confirm the variant already exists

Verify the variant's constant, predicate, registry entry, and adapter are already in place per
the "Adding Behavioral Variant Checklist" above. This section does not create variants.

#### Step 2 — Confirm an override is actually needed

Compare the proposed arrangement to the app's current baseline
(`kRemoteLayoutItemDefinitions`, `remote_layout_item_definitions.dart:92-228`). Only proceed
if there's a real reason for this brand+variant to differ — matching its physical remote is
one valid reason, but so is "this arrangement is simply more usable for this device in the
app." If nothing justifies a difference, **do not add an entry** — let it resolve via tier 3.
An identical entry is pure duplication with no behavioral effect.

#### Step 3 — Gather whatever reference informs the override

If physical-remote parity is the reason, determine what the real remote has: product manual,
manufacturer product photos, or a physical unit. If the reason is app-UX judgment instead,
document that reasoning just as clearly. Either way, note the justification in a comment next
to the entry (see Step 4) so a future maintainer knows *why* it exists — this has no other
authoritative home in the codebase.

#### Step 4 — Build the item list

Reuse existing ids/icons/labels/footprints from `kRemoteLayoutItemDefinitionById` for any
button that matches the baseline; only override `col`/`row`/`width`/`height` for buttons
that are repositioned, and add new `RemoteLayoutItemDefinition` entries only for buttons the
baseline doesn't have at all.

**File:** `lib/remote_control/presentation/widgets/remote_layout_defaults.dart`

```dart
static final Map<(TvBrand, String), List<RemoteLayoutItemDefinition>> _map = {
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

#### Step 5 — Register and verify fallback

Confirm the new entry only affects its exact `(brand, variant)` key — pairing a different,
unlisted variant of the same brand must still fall through to that brand's default-variant
entry (tier 2) or the global baseline (tier 3), not accidentally pick up this override.

#### Step 6 — No separate drawer step

Commands the adapter supports but that don't appear in this entry's item list automatically
start in the drawer on a fresh pairing — no entry for a command in the positions map means
it's not positioned, and the drawer is `supportedCommands` minus positioned items
(`resolveDefaultLayoutItemZone`, `remote_layout_item_definitions.dart`) — no additional wiring
needed here.

### Adding Variant Remote Layout Checklist

- [ ] Confirmed the protocol variant already exists per the "Adding Behavioral Variant Checklist" above (constant, predicate, registry entry, adapter)
- [ ] Confirmed there's a real reason for this brand+variant to diverge from the baseline before adding an entry — no override added without one
- [ ] Documented that reason in a comment on the entry (physical remote reference, or app-UX rationale if that's the justification instead)
- [ ] Built the `List<RemoteLayoutItemDefinition>` entry, reusing existing ids/icons/labels/footprints where the button matches; new ids only where genuinely new
- [ ] Verified every id used has a `requiredCommands`/primary-command mapping
- [ ] Registered the entry in `RemoteLayoutDefaults._map` keyed by `(brand, variant)`
- [ ] Test: `layoutFor` resolves to this entry for the exact `(brand, variant)`
- [ ] Test: a different, unlisted variant of the same brand still falls through correctly (tier 2 or tier 3)
- [ ] Test: `_buildLayoutDefaultsForDevice` produces the new layout end-to-end for a device stamped with this variant
- [ ] Confirmed the default layout is visible to free-tier users too (not Pro-gated) — only editing/repositioning is Pro-gated

### Adding Variant Remote Layout Design notes

**Why does `RemoteLayoutDefaults` only hold exceptions, not every brand+variant?**  
Adding an entry has a real cost (research or design judgment) and only pays off when there's
an actual reason to diverge. Seeding every key with a duplicate of the baseline was considered
and rejected — it adds maintenance surface with no behavioral difference.

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
`_map` is a single `static final` literal in this one file — fine at a handful of entries,
but each entry can hold a full `List<RemoteLayoutItemDefinition>` (heavier than
`TvCapabilities`'s `Set<DeviceCapability>` entries), so a few dozen real overrides would make
this file hard to scan. If that happens, split the data across per-brand files and merge them
with the spread operator — `layoutFor()` and every caller stay unchanged, since nothing
outside this class ever reads `_map` directly:

```dart
// samsung_layout_overrides.dart
final Map<(TvBrand, String), List<RemoteLayoutItemDefinition>> samsungLayoutOverrides = {
  (TvBrand.samsung, SamsungProtocolVariants.frameVariant): [...],
};

// remote_layout_defaults.dart
static final Map<(TvBrand, String), List<RemoteLayoutItemDefinition>> _map = {
  ...samsungLayoutOverrides,
  ...lgLayoutOverrides,
};
```

Not worth building ahead of need — do this once the single-file map actually becomes hard to
read, not before.

---

---