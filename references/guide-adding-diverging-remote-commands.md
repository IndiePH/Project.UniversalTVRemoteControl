# Guide: Diverging a Variant's Remote Commands

A device variant sometimes needs one or two commands to produce a different payload than
its brand's default mapping — a different Disney+ app id for a specific region/model, a
different key code alias for one firmware line, and so on — without anything else about
how the device is talked to changing. This guide covers that one case: overriding a
handful of `RemoteCommand` → payload mappings for a variant, without duplicating the
brand's whole `CommandKeyMap` or its whole adapter.

**Prerequisite:** the protocol variant itself must already exist — see
`references/guide-adding-protocol-variant.md`. This guide does not create variants; it
only refines that guide's **Step 3 (create a variant-specific adapter)** for the common
case where the variant's adapter needs to change *what a command sends*, not *how the
device is connected to, paired with, or read from*. Everything else in that guide's
checklist (variant constant, predicate, registry entry, DI registration) applies
unchanged — read it first if you haven't already.

---

## How the system works

### The flow

```
BrandRoutedRemoteCommandService
  └─ _adapters[(device.brand, device.protocolVariant)]   → exact-match lookup, no fallback
       └─ adapter.sendCommand(device, command)
            └─ _keyMapper.keyCodesFor(command)            → List<String> (payload)
```

`BrandRoutedRemoteCommandService` builds its lookup map from `(a.brand, a.protocolVariant)`
for every adapter passed in at DI time (`brand_routed_remote_command_service.dart:18`) and
resolves by exact key — there is no fallback from a variant to its brand's default adapter.
That means the **adapter** is the unit the router selects by, so a new variant always needs
its own adapter instance in that list. What varies between adapters, though, does not have
to be an entire reimplementation — `TvBrandAdapter`'s connection, pairing, and lifecycle
methods can be inherited verbatim; only the mapping from `RemoteCommand` to outgoing payload
needs to change, and that mapping already lives behind its own abstraction.

### CommandKeyMap

**File:** `lib/remote_control/data/adapters/command_key_map.dart`

```dart
abstract class CommandKeyMap {
  const CommandKeyMap();

  List<String> keyCodesFor(RemoteCommand command);

  String? primaryKeyCodeFor(RemoteCommand command) { ... }
}
```

Every brand adapter holds a `CommandKeyMap` and calls `keyCodesFor(command)` to get the
payload it sends over the transport (see `SamsungAdapter.sendCommand`,
`samsung_adapter.dart:104-116`). The base adapter already accepts one as an **optional
constructor parameter**, defaulting to the brand's own mapper:

```dart
// samsung_adapter.dart
SamsungAdapter({required this._transportClient, CommandKeyMap? keyMapper})
  : _keyMapper = keyMapper ?? const SamsungKeyMapper();
```

That optional parameter is the seam this guide uses. A variant adapter doesn't need to
supply a whole new `CommandKeyMap` implementation — it needs to supply the *same* mapper
with a *few entries swapped*.

### VariantKeyMap

A generic decorator over `CommandKeyMap` does exactly that, and is reused across every
brand and every variant — it is not brand-specific and not written once per variant:

```dart
class VariantKeyMap extends CommandKeyMap {
  const VariantKeyMap(this._base, this._overrides);
  final CommandKeyMap _base;
  final Map<RemoteCommand, List<String>> _overrides;

  @override
  List<String> keyCodesFor(RemoteCommand command) =>
      _overrides[command] ?? _base.keyCodesFor(command);
}
```

`keyCodesFor` checks the override map first and falls through to the base mapper for every
command the variant doesn't touch. The base mapper's full command set stays live and
current automatically — if the brand's default mapper later adds support for a new
command, every variant built on `VariantKeyMap` picks it up for free, with zero edits.

---

## Step-by-step: diverging one command for a variant

The example below gives a hypothetical `Samsung Frame` variant (per the example already
used in `guide-adding-protocol-variant.md`) a region-specific Disney+ app id, while leaving
every other Samsung command mapping untouched.

### Step 1 — Confirm the variant already exists

Verify the variant's constant, predicate, and registry entry are already in place per
`guide-adding-protocol-variant.md`'s checklist:

```dart
// samsung_protocol_variants.dart
abstract final class SamsungProtocolVariants {
  static const String defaultVariant = TvDevice.defaultProtocolVariant;
  static const String frameVariant = 'samsung_frame';
  static bool isFrameSeries(TvDeviceInfo info) { ... }
}
```

If it doesn't exist yet, create it there first — this guide only covers what the variant's
adapter does once it can already be resolved and routed to.

### Step 2 — Build the override map

Identify exactly which `RemoteCommand`s the variant needs to differ on, and write only
those as a `Map<RemoteCommand, List<String>>`. Do not re-list commands that are unchanged
— that's what `VariantKeyMap`'s fallback to `_base` is for.

```dart
const _frameOverrides = <RemoteCommand, List<String>>{
  RemoteCommand.disneyPlus: [
    '$samsungLaunchPrefix:region-specific-disney-app-id',
  ],
};
```

### Step 3 — Compose the variant's adapter

Extend the brand's **existing adapter class**, not `TvBrandAdapter` directly. Override only
the `protocolVariant` getter and pass a `VariantKeyMap` through the base adapter's existing
`keyMapper` constructor parameter — everything else (`sendCommand`, `connect`,
`preparePairing`, `queryDeviceInfo`, ...) is inherited unchanged.

**Create:** `lib/remote_control/data/adapters/samsung_frame_adapter.dart`

```dart
class SamsungFrameAdapter extends SamsungAdapter {
  SamsungFrameAdapter({required super.transportClient})
    : super(
        keyMapper: VariantKeyMap(const SamsungKeyMapper(), const {
          RemoteCommand.disneyPlus: [
            '$samsungLaunchPrefix:region-specific-disney-app-id',
          ],
        }),
      );

  @override
  String get protocolVariant => SamsungProtocolVariants.frameVariant;
}
```

That's the entire class. No transport calls, no pairing logic, no connection-state
plumbing — all of it comes from `SamsungAdapter` unchanged.

### Step 4 — Register the adapter in DI

This is the same DI step `guide-adding-protocol-variant.md` already documents — nothing
new here beyond adding the one new instance alongside the brand's default adapter:

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

---

## Checklist

- [ ] Confirmed the protocol variant already exists per `guide-adding-protocol-variant.md` (constant, predicate, registry entry)
- [ ] Identified exactly which `RemoteCommand`s diverge for this variant — no unchanged commands re-listed in the override map
- [ ] Variant adapter class **extends** the brand's existing adapter (not `TvBrandAdapter` directly)
- [ ] Adapter overrides only `protocolVariant` and composes a `VariantKeyMap` through the base adapter's `keyMapper` constructor parameter
- [ ] Adapter registered in DI config alongside the brand's default adapter, per `guide-adding-protocol-variant.md`'s Step 3/DI registration
- [ ] If the variant also adds or removes which commands are supported (not just their payload), `supportedCommands` is explicitly overridden in the same subclass
- [ ] Test: `keyCodesFor` returns the overridden payload for the diverging command(s)
- [ ] Test: `keyCodesFor` falls through to the base mapper's payload for every non-overridden command
- [ ] Test: `sendCommand` on the variant adapter produces the correct transport payload end-to-end

---

## Design notes

**Why not give the variant its own, independent `CommandKeyMap` class?**  
A full duplicate mapper has to re-list every command the brand supports, not just the ones
that differ. That duplicates every unrelated mapping — a DRY violation — and it silently
goes stale: if the base mapper later adds a new command or changes an existing key code,
every duplicated variant mapper keeps the old, now-wrong behavior until someone remembers
to update it by hand. `VariantKeyMap` reads from `_base` for anything it doesn't
explicitly override, so it can never drift out of sync with the base mapper on the
commands it doesn't touch.

**Why does a new variant still need its own adapter class — isn't that the same
duplication problem?**  
No — it's a different axis. `BrandRoutedRemoteCommandService` selects by the exact key
`(brand, protocolVariant)` (`brand_routed_remote_command_service.dart:18`), so the adapter
*is* the unit of routing; one adapter instance per resolvable variant is required by that
design, not incidental to it. What makes this cheap is that the adapter subclass carries no
new behavior — `SamsungFrameAdapter` overrides a getter that returns a different string and
threads a different key mapper through a constructor parameter that already existed for
this purpose. Every method that actually talks to the TV — `sendCommand`, `connect`,
`preparePairing`, `queryDeviceInfo`, `watchConnectionState` — is inherited from
`SamsungAdapter` untouched. That's Liskov-safe: nothing about the adapter's contract or
behavior is being overridden, only the data it's constructed with. A ~5-10 line subclass
per variant is the cost of that design, not a smell in it.

**Why is `VariantKeyMap` itself never subclassed per variant?**  
Because it has no brand- or variant-specific logic to specialize — it's a generic map
lookup with a fallback. The same class is reused for every variant of every brand,
parameterized only by which `_base` mapper and which `_overrides` map are passed in. One
adapter class per variant is required by the routing design above; one keymapper class per
variant is not, and would just be the duplication problem restated.

**What if a variant needs to add or remove which commands it supports, not just how they're
sent?** `VariantKeyMap` only changes the payload for commands the adapter already attempts
to send — it has no effect on `TvBrandAdapter.supportedCommands`, which is a separate,
independently-declared getter (see `SamsungAdapter.supportedCommands`,
`samsung_adapter.dart:51`). If a variant genuinely supports a different command set than
its brand's default — not just different payloads for the same commands — override
`supportedCommands` explicitly in the same adapter subclass. There is no automatic
mechanism today that keeps `supportedCommands` and the key-map overrides in sync; that's a
manual responsibility of whoever writes the variant adapter.
