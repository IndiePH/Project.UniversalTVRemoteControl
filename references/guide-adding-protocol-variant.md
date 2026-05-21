# Guide: Adding a New Protocol Variant

A protocol variant is a string tag on `TvDevice.protocolVariant` that tells an adapter
which behavioral path to take for a specific device model. The variant is stamped once,
at pairing time, and persisted — so every subsequent command dispatch already knows which
path to use.

---

## How the system works

### The flow

```
preparePairing()
  └─ adapter.queryDeviceInfo()        → TvDeviceInfo? (model, firmware)
  └─ variantRegistry.resolve()        → String (variant tag)
  └─ TvCapabilities().capabilitiesFor() → Set<DeviceCapability>
  └─ device.copyWith(protocolVariant: ..., capabilities: ...) → stored / returned
```

After pairing, `TvDevice.protocolVariant` is available on every call to `sendCommand`,
`sendText`, etc., so adapters can branch on it without re-querying the TV.

### DefaultVariantResolutionRegistry

**File:** `lib/remote_control/data/variant_resolution_registry.dart`

```dart
class _VariantResolutionEntry {
  final TvBrand brand;
  final bool Function(TvDeviceInfo info) matches; // ← the predicate
  final String variant;
}
```

`resolve()` walks `_entries` in order and returns the **first** entry where:

```
entry.brand == brand  &&  entry.matches(info)
```

All current entries use `(_) => true` — a catch-all that always matches. To add a
specific variant you add a **more-specific entry before the catch-all** for that brand.

### TvCapabilities

**File:** `lib/remote_control/domain/models/tv_capabilities.dart`

Holds all capability sets indexed by `(TvBrand, String variant)`. After the variant is
resolved by `VariantResolutionRegistry`, capabilities are looked up directly by key — no
predicate re-evaluation needed.

```dart
static const Map<(TvBrand, String), Set<DeviceCapability>> _map = { ... };

Set<DeviceCapability> capabilitiesFor(TvBrand brand, [String? variant]) {
  final v = variant ?? TvDevice.defaultProtocolVariant;
  return _map[(brand, v)] ?? _map[(brand, TvDevice.defaultProtocolVariant)] ?? {};
}
```

Unknown variants fall back to the brand's default-variant entry. This is used at every
call site as `const TvCapabilities().capabilitiesFor(brand, variant)`.

---

## Step-by-step: adding a new protocol variant

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

Add a new `_VariantResolutionEntry` **before** the existing catch-all for the brand.

**File:** `lib/remote_control/data/variant_resolution_registry.dart`

```dart
static final _entries = <_VariantResolutionEntry>[
  // ── Samsung ──────────────────────────────────────────────────────────────
  _VariantResolutionEntry(              // ← specific rule, checked first
    brand: TvBrand.samsung,
    matches: SamsungProtocolVariants.isFrameSeries, // ← predicate
    variant: SamsungProtocolVariants.frameVariant,
  ),
  _VariantResolutionEntry(              // ← catch-all stays last for the brand
    brand: TvBrand.samsung,
    matches: (_) => true,
    variant: SamsungProtocolVariants.defaultVariant,
  ),
  // ── LG ───────────────────────────────────────────────────────────────────
  _VariantResolutionEntry(
    brand: TvBrand.lg,
    matches: (_) => true,
    variant: TvDevice.defaultProtocolVariant,
  ),
  // ...
];
```

**`matches` receives a `TvDeviceInfo`** populated by `adapter.queryDeviceInfo()`. The
available fields are:

| Field              | Source                       | Notes                              |
|--------------------|------------------------------|------------------------------------|
| `modelIdentifier`  | `queryDeviceInfo` → adapter  | Null if the brand doesn't probe    |
| `firmwareVersion`  | `queryDeviceInfo` → adapter  | Null if the brand doesn't probe    |

If `info` itself is null (brand returned nothing from `queryDeviceInfo`), `resolve()`
short-circuits and returns `TvDevice.defaultProtocolVariant` without hitting any entry.
**Adapters that don't currently probe device info should return `TvDeviceInfo()` (empty,
non-null) rather than `null`.** An empty `TvDeviceInfo` lets the entry list run — the
catch-all still returns `defaultProtocolVariant`, but specific model rules become
reachable as soon as the transport starts providing data.

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
final commandService = BrandRoutedRemoteCommandService(
  adapters: [
    SamsungAdapter(transportClient: sl<SamsungTransportClient>()),      // default
    SamsungFrameAdapter(transportClient: sl<SamsungTransportClient>()), // ← new
    LgAdapter(transportClient: sl<LgTransportClient>()),
    HisenseAdapter(transportClient: sl<HisenseTransportClient>()),
  ],
  variantRegistry: sl<VariantResolutionRegistry>(),
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

## Checklist

- [ ] Variant constant added to `*ProtocolVariants`
- [ ] Predicate added to `*ProtocolVariants` alongside the constant
- [ ] Entry added in `DefaultVariantResolutionRegistry._entries` before the brand catch-all
- [ ] `queryDeviceInfo` returns `TvDeviceInfo` with a populated `modelIdentifier` (or `firmwareVersion`) for the matching device
- [ ] Variant-specific adapter class created, `protocolVariant` getter returns the new constant
- [ ] Adapter registered in DI config alongside the existing default adapter
- [ ] Capability override added to `TvCapabilities._map` (only if capabilities differ from brand default)
- [ ] Test: registry resolves the correct variant for a matching `TvDeviceInfo`
- [ ] Test: registry falls through to `default` for a non-matching `TvDeviceInfo`
- [ ] Test: adapter produces the correct transport command for the new variant

---

## Design notes

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

**Why does the catch-all exist in `VariantResolutionRegistry`?**  
`resolve()` needs a guaranteed return value for every brand even when no specific rule
matches. The catch-all at the end of each brand's entries ensures graceful fallback
without a null check at the call site.
