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
  └─ adapter.queryDeviceInfo()   → TvDeviceInfo? (model, firmware)
  └─ variantRegistry.resolve()   → String (variant tag)
  └─ capabilityRegistry.resolve() → Set<DeviceCapability>
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

### DefaultTvModelCapabilityRegistry

**File:** `lib/remote_control/domain/models/tv_model_capability_registry.dart`

Follows the same entry pattern as `DefaultVariantResolutionRegistry`. Each
`_CapabilityEntry` carries a brand, a `matches` predicate on `modelIdentifier`, and the
resolved capability set. `resolve()` walks entries in order and returns the first match;
brand-level catch-alls ensure every brand always resolves.

---

## Step-by-step: adding a new protocol variant

The example below adds a hypothetical `Samsung Frame` variant that uses a different
power-toggle command path.

### Step 1 — Declare the variant constant

Add a new constant to the brand's `*ProtocolVariants` class.

**File:** `lib/remote_control/data/adapters/samsung/samsung_protocol_variants.dart`

```dart
abstract final class SamsungProtocolVariants {
  static const String defaultVariant = TvDevice.defaultProtocolVariant;
  static const String frameVariant = 'samsung_frame'; // ← add this
}
```

Use a unique, lowercase, underscore-separated string. It is persisted to
`SharedPreferences` as-is (via `TvDevice.toJson`), so treat it as a stable identifier —
never rename it once shipped.

### Step 2 — Register the matching rule

Add a new `_VariantResolutionEntry` **before** the existing catch-all for the brand.

**File:** `lib/remote_control/data/variant_resolution_registry.dart`

```dart
static final _entries = <_VariantResolutionEntry>[
  // ── Samsung ──────────────────────────────────────────────────────────────
  _VariantResolutionEntry(              // ← specific rule, checked first
    brand: TvBrand.samsung,
    matches: (info) {
      final model = info.modelIdentifier ?? '';
      return model.startsWith('QM') || model.startsWith('LS');
    },
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
  capabilityRegistry: sl<TvModelCapabilityRegistry>(),
);
```

**Note — routing change required in `BrandRoutedRemoteCommandService`:**
The service currently routes by brand alone (`Map<TvBrand, TvBrandAdapter>`). To
support multiple adapters per brand it needs to route by `(brand, variant)` instead.
The `TvBrandAdapter.protocolVariant` getter is already declared for this purpose.
That routing change must land before a variant adapter can be dispatched correctly.

### Step 4 — Capability override (only if needed)

If the new variant also changes which capabilities the device has, add a
`_CapabilityEntry` before the brand catch-all in `DefaultTvModelCapabilityRegistry`,
following the same first-match ordering as `DefaultVariantResolutionRegistry`.

**File:** `lib/remote_control/domain/models/tv_model_capability_registry.dart`

```dart
// Entry type (mirrors _VariantResolutionEntry)
class _CapabilityEntry {
  const _CapabilityEntry({
    required this.brand,
    required this.matches,
    required this.capabilities,
  });

  final TvBrand brand;
  final bool Function(String? modelIdentifier) matches;
  final Set<DeviceCapability> capabilities;
}

class DefaultTvModelCapabilityRegistry implements TvModelCapabilityRegistry {
  const DefaultTvModelCapabilityRegistry();

  static final _entries = <_CapabilityEntry>[
    // ── Samsung ──────────────────────────────────────────────────────────────
    _CapabilityEntry(                           // ← specific rule, checked first
      brand: TvBrand.samsung,
      matches: (model) =>
          model != null &&
          (model.startsWith('QM') || model.startsWith('LS')),
      capabilities: {
        DeviceCapability.keyCommands,
        DeviceCapability.powerControl,           // no textInput on Frame series
      },
    ),
    _CapabilityEntry(                           // ← catch-all
      brand: TvBrand.samsung,
      matches: (_) => true,
      capabilities: TvBrand.samsung.defaultCapabilities,
    ),
    // ── LG ───────────────────────────────────────────────────────────────────
    _CapabilityEntry(
      brand: TvBrand.lg,
      matches: (_) => true,
      capabilities: TvBrand.lg.defaultCapabilities,
    ),
    // ── Hisense ──────────────────────────────────────────────────────────────
    _CapabilityEntry(
      brand: TvBrand.hisense,
      matches: (_) => true,
      capabilities: TvBrand.hisense.defaultCapabilities,
    ),
  ];

  @override
  Set<DeviceCapability> resolve({
    required TvBrand brand,
    required String? modelIdentifier,
  }) {
    for (final entry in _entries) {
      if (entry.brand == brand && entry.matches(modelIdentifier)) {
        return entry.capabilities;
      }
    }
    return brand.defaultCapabilities;
  }
}
```

The `matches` predicate here receives `modelIdentifier` directly (a `String?`) rather
than a full `TvDeviceInfo`, because that is the only probe data the capability registry
receives at the call site.

Avoid this step unless capabilities genuinely differ — the variant tag is the right
place for behavioral branching, not the capability set.

---

## Checklist

- [ ] Variant constant added to `*ProtocolVariants`
- [ ] Entry added in `DefaultVariantResolutionRegistry._entries` before the brand catch-all
- [ ] `queryDeviceInfo` returns `TvDeviceInfo` with a populated `modelIdentifier` (or `firmwareVersion`) for the matching device
- [ ] Variant-specific adapter class created, `protocolVariant` getter returns the new constant
- [ ] Adapter registered in DI config alongside the existing default adapter
- [ ] `BrandRoutedRemoteCommandService` routes by `(brand, variant)` (required before dispatch works)
- [ ] Capability override added to `DefaultTvModelCapabilityRegistry` (only if capabilities differ)
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

**Why does the catch-all exist?**  
`resolve()` needs a guaranteed return value for every brand even when no specific rule
matches. The catch-all at the end of each brand's entries ensures graceful fallback
without a null check at the call site.
