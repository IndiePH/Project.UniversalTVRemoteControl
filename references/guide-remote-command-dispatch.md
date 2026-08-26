# Guide: Remote Command Dispatch

A `RemoteCommand` (`power`, `netflix`, `dpadUp`, ...) becomes a real action on a TV in two
steps: a brand's `CommandKeyMap` resolves it to a `CommandPayload` — the data to send, and
*how* to send it — and the adapter's `sendCommand` switches on that payload's type to call the
matching transport method. A device variant sometimes needs to change that resolution for just
a handful of commands — a different Disney+ app id for one region, a different key alias for
one firmware line — without duplicating the brand's whole key map or its whole adapter. This
guide covers both: the `CommandPayload` contract itself, and the per-variant override seam built
on top of it.

## Contents

- [The `CommandPayload` contract](#the-commandpayload-contract)
- [Why this design, not a marker set](#why-this-design-not-a-marker-set)
- [Writing a key mapper](#writing-a-key-mapper)
- [Writing `sendCommand`](#writing-sendcommand)
  - [Why `sealed`, and why `default:`](#why-sealed-and-why-default)
- [Writing `supportedCommands`](#writing-supportedcommands)
- [Diverging a variant's commands](#diverging-a-variants-commands)
- [Step-by-step: diverging one command for a variant](#step-by-step-diverging-one-command-for-a-variant)
- [Checklist](#checklist)
- [Design notes](#design-notes)
- [Adding a brand-specific payload type](#adding-a-brand-specific-payload-type)
- [Testing](#testing)

---

## The `CommandPayload` contract

> **Status: this is the live contract.** `CommandKeyMap.payloadFor(RemoteCommand) ->
> CommandPayload?` (`lib/remote_control/data/adapters/command_key_map.dart`) is what every
> adapter — Samsung, LG, AndroidTv, TclGoogleTv, TclRoku, TclLegacyWifi, Hisense, Sony — uses
> today. There is no `keyCodesFor`/`List<String>` contract left anywhere in `lib/`; it was fully
> replaced by this one.

### Why this exists

Before this was unified, six adapters dispatched "app-launch" commands (Netflix, Disney+, Prime
Video, YouTube, web) through three different shapes: Samsung and LG hid a `LAUNCH:`-prefixed
sentinel string inside the key mapper and let the *transport client* `startsWith`-sniff it;
AndroidTv and TclGoogleTv kept a second, byte-for-byte duplicated map on the adapter (checked
before the keymapper), and TclRoku kept its own separate map in that same shape; Hisense kept a
tuple-returning switch on the adapter with the keymapper deliberately left empty for those
commands. Three shapes for the same underlying idea: "this command doesn't send a raw key code,
it launches an app, and needs different data and a different transport call to do it."

`CommandPayload` collapsed those three shapes into one: every command's dispatch information —
both the data to send and *how* to send it — lives in exactly one place, the key map. Samsung's
`LAUNCH:` sentinel is gone entirely (its app-launch commands are plain `AppLink` entries now);
AndroidTv/TclGoogleTv's adapter-level `_appLinks` map is gone (folded into the keymapper, via
`VariantKeyMap` for TclGoogleTv's `market://` override — see "Diverging a variant's commands"
below); TclRoku's `_appIds` map is gone the same way (`TclRokuKeyMapper`'s four launch commands
are now plain `AppLink` entries carrying Roku channel ids); Hisense's keymapper carries real
`VidaaLaunch` entries instead of being left empty. LG's `LAUNCH:`/`POINTER:`/`TOGGLE:` sentinels
are gone too (`references/changelog.md`'s 2026-08-26 entry) — its app-launch commands are
`AppLink` entries, pointer-socket input (`dpad*`/`home`/`back`) is `PointerCommand(button)`, and
its three stateful toggles (`power`/`playPause`/`mute`) are `ToggleCommand(ToggleKind)`.

### The contract

**File:** `lib/remote_control/data/adapters/command_key_map.dart`

```dart
sealed class CommandPayload {
  const CommandPayload();
}

/// Dispatched via `sendKey`. One or more ordered fallback key-code aliases to try in order —
/// the same meaning the old `keyCodesFor`'s `List<String>` used to carry.
final class KeySequence extends CommandPayload {
  const KeySequence(this.codes);
  final List<String> codes;
}

/// Dispatched via `sendAppLink` (or a brand's equivalent, e.g. `launchApp`). Carries the raw
/// app id or deep-link URI with no sentinel prefix — the payload's *type* is what says
/// "this is an app link," so nothing downstream needs to parse a string convention.
final class AppLink extends CommandPayload {
  const AppLink(this.uri);
  final String uri;
}

/// Dispatched via `launchVidaaApp` (Hisense-specific — see "Adding a brand-specific payload
/// type" below for when a new one like this is actually warranted).
final class VidaaLaunch extends CommandPayload {
  const VidaaLaunch(this.displayName, this.url);
  final String displayName;
  final String url;
}

abstract class CommandKeyMap {
  const CommandKeyMap();

  /// Returns the payload for [command], or `null` if this brand/variant doesn't support it.
  CommandPayload? payloadFor(RemoteCommand command);
}
```

Each concrete subclass also overrides `==`/`hashCode` (by field, e.g. `KeySequence`'s compares
its `codes` list element-by-element) — omitted above for brevity, but real, and required: without
it, two separately-constructed payloads with identical data wouldn't compare equal, and the
`expect(mapper.payloadFor(...), const AppLink(...))`-style assertions in "Testing" below would
fail even when the mapping is correct.

**The rule that makes this work:** one `CommandPayload` subclass per **transport method**, never
per data shape. `KeySequence` covers "one code" and "five fallback codes" identically — arity is
a detail *inside* the subclass, not a reason for a new one. A new subclass is only warranted when
a genuinely new transport method needs data no existing subclass can carry (see "Adding a
brand-specific payload type" below).

### Why this design, not a marker set

The first draft added a `Set<RemoteCommand> appLinkCommands` per adapter, checked before calling
the keymap, instead of changing what the keymap returns. It was dropped for two reasons: the
`Set` and the keymap were two independent collections that had to be kept in sync by hand — a
command listed in one but not the other was a real, easy-to-make mistake — and nothing about a
`Set` gave a way to return Hisense's two-piece `(displayName, url)` data. Making `payloadFor`'s
return type itself carry the dispatch decision removes the second collection entirely: the
payload and the "how to send it" decision are the same value, so they can't disagree. This is
also why the method was renamed from `keyCodesFor` to `payloadFor` in the same change rather
than kept and renamed later — the return type was changing regardless, so the rename happened
in the same pass instead of a second migration over the same call sites. (Full historical
detail lives in the 2026-08-22 `changelog.md` entry — this section covers the load-bearing
reasoning only.)

---

## Writing a key mapper

A single command with a plain key code:

```dart
RemoteCommand.power: const KeySequence(['KEY_POWER']),
```

A command with several fallback aliases the device might recognize (order matters — first match
wins):

```dart
RemoteCommand.back: const KeySequence(['KEY_RETURNS', 'KEY_RETURN', 'KEY_BACK']),
```

An app-launch command — note there's no prefix, no sentinel, nothing to parse downstream. Prefer
an `https://` App Link URI over the legacy `market://launch?id=...` scheme (Android TV/Google TV
builds have been dropping support for the latter — see `android_tv_key_mapper.dart`; `market://`
still shows up as `TclGoogleTvAdapter`'s explicit, hardware-unverified override, not as the
default to copy for a new brand):

```dart
RemoteCommand.netflix: const AppLink('https://www.netflix.com/title'),
```

A command this brand/variant doesn't support at all — omit the entry; `payloadFor` returns
`null` for any key missing from the underlying map.

---

## Writing `sendCommand`

Every adapter's `sendCommand` becomes the same shape — one exhaustive switch over what the key
map returns:

```dart
@override
Future<void> sendCommand({
  required TvDevice device,
  required RemoteCommand command,
}) async {
  final payload = _keyMap.payloadFor(command);
  if (payload == null) {
    throw UnsupportedError('No Brand key mapping for command: $command');
  }
  await _transportClient.connect(deviceId: device.id);
  switch (payload) {
    case KeySequence(:final codes):
      for (final code in codes) {
        await _transportClient.sendKey(deviceId: device.id, keyCode: code);
      }
    case AppLink(:final uri):
      await _transportClient.sendAppLink(deviceId: device.id, appLink: uri);
    default:
      throw UnsupportedError(
        'Brand has no dispatch path for ${payload.runtimeType}.',
      );
  }
}
```

Real cases for whatever this brand actually dispatches, one `default:` at the end for
everything else — see "Why `sealed`, and why `default:`" below for why it's shaped this way
instead of one case per `CommandPayload` subclass.

**Each `case` calls a real method on `_transportClient`.** If the dispatch you need doesn't
have one yet — a brand's first `AppLink` command, or a payload shape that needs a transport
call no existing method covers — the method has to be added to that brand's transport client
before `sendCommand` can call it. Concretely, that means two edits, not one:

1. The abstract interface (e.g. `SamsungTransportClient`, `LgTransportClient`,
   `HisenseTransportClient`) gains the new method signature.
2. The concrete implementation (e.g. `SamsungWebSocketTransportClient`) implements it — this
   is where the actual network/socket/MQTT call for that dispatch action lives.

If any test-local fake or debug fake (e.g. `FakeSamsungTransportClient`) implements that
interface directly with `implements` rather than `extends`, it also needs the new method added
by hand — `implements` never inherits a default method body, even if the interface method has
one, so every direct implementer has to be updated or the project won't compile. This is exactly
what happened when Samsung's `AppLink` case was added: `launchApp` had to be declared on
`SamsungTransportClient` and implemented on `SamsungWebSocketTransportClient`, and every fake
implementing that interface — including the 5 test-local ones in `samsung_test_lane_test.dart`
— needed the same method added before the suite would compile again.

Don't add a new `CommandPayload` subclass just to get a new transport method, though — check
first whether the dispatch you need is actually a `KeySequence` with unusual-looking codes
(still just `sendKey`) before assuming it needs its own type. See "Adding a brand-specific
payload type" below for when a new subclass is actually warranted.

### Why `sealed`, and why `default:`

`CommandPayload` is `sealed` so every `switch` over it is exhaustiveness-checked: Dart knows
every direct subtype and can prove (or refuse to compile) that a given switch accounts for all
of them. That's also why a brand-specific type like `VidaaLaunch` (Hisense-only) or
`PointerCommand`/`ToggleCommand` (LG-only) lives here in `command_key_map.dart` rather than in
a brand-specific file — `sealed` requires every direct subtype to be declared in the *same
library* as the sealed class itself, so there's no way to split them out and keep them usable
from `payloadFor`'s shared return type.

A fully exhaustive switch — one explicit `case` per `CommandPayload` subtype, no `default` —
was the original shape, and it has a real cost: every brand-specific type touches every adapter
that doesn't support it, whether or not that adapter will ever produce it. Two LG-only types
across six non-LG adapters was 12 near-identical throw-lines added in one PR for that reason.
That's O(brands × types) growth with no ceiling as more brand-specific payload types get added.

The current shape instead: real cases for whatever a brand actually dispatches, then one
`default: throw UnsupportedError('$Brand has no dispatch path for ${payload.runtimeType}.')`
for everything else — one line per adapter, not one line per (adapter, unsupported type) pair.
The cost is real: `default:` gives up the compiler's guarantee. Adding a new `CommandPayload`
subtype no longer forces every adapter to consciously decide whether it supports it — the code
keeps compiling either way. What replaces that guarantee is
`test/lib/remote_control/data/adapters/supported_commands_dispatch_test.dart`: for every command
a brand's own key map claims to support (`payloadFor(command) != null`), it dispatches that
command through a fake transport and fails if it hits `UnsupportedError`. That catches the
specific failure mode `default:` reopens — a key map returning a payload type its own adapter's
switch doesn't actually have a real case for — behaviorally, at test time, instead of
structurally, at compile time.

---

## Writing `supportedCommands`

Uniform across every brand, no per-adapter special-casing needed:

```dart
@override
Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands
    .where((command) => _keyMap.payloadFor(command) != null)
    .toSet();
```

This is safe for every adapter precisely because dispatch data and support are now the same
fact: a command is supported if and only if `payloadFor` returns something, and `sendCommand`
can never be asked to handle a command `supportedCommands` didn't already claim to support.

---

## Diverging a variant's commands

A device variant sometimes needs one or two commands to produce a different payload than its
brand's default mapping — a different Disney+ app id for a specific region/model, a different
key code alias for one firmware line, and so on — without anything else about how the device is
talked to changing. This section covers that one case: overriding a handful of `RemoteCommand` →
`CommandPayload` mappings for a variant, without duplicating the brand's whole `CommandKeyMap` or
its whole adapter.

**Prerequisite:** the protocol variant itself must already exist — see
`references/guide-protocol-variants.md`. This section does not create variants; it only refines
that guide's **Step 3 (create a variant-specific adapter)** for the common case where the
variant's adapter needs to change *what a command sends*, not *how the device is connected to,
paired with, or read from*. Everything else in that guide's checklist (variant constant,
predicate, registry entry, DI registration) applies unchanged — read it first if you haven't
already.

### The flow

```
BrandRoutedRemoteCommandService
  └─ _adapters[(device.brand, device.protocolVariant)]   → exact-match lookup, no fallback
       └─ adapter.sendCommand(device, command)
            └─ _keyMapper.payloadFor(command)             → CommandPayload? (payload)
```

`BrandRoutedRemoteCommandService` builds its lookup map from `(a.brand, a.protocolVariant)`
for every adapter passed in at DI time (`brand_routed_remote_command_service.dart:20`) and
resolves by exact key (`_adapterFor`, `brand_routed_remote_command_service.dart:303`) — there
is no fallback from a variant to its brand's default adapter. That means the **adapter** is
the unit the router selects by, so a new variant always needs its own adapter instance in
that list. What varies between adapters, though, does not have to be an entire
reimplementation — `TvBrandAdapter`'s connection, pairing, and lifecycle methods can be
inherited verbatim; only the mapping from `RemoteCommand` to outgoing payload needs to
change, and that mapping already lives behind its own abstraction (see "The `CommandPayload`
contract" above).

Every brand adapter holds a `CommandKeyMap` and calls `payloadFor(command)` to get the
payload it sends over the transport (see `SamsungAdapter.sendCommand`,
`samsung_adapter.dart:109-128`). The base adapter already accepts one as an **optional
constructor parameter**, defaulting to the brand's own mapper:

```dart
// samsung_adapter.dart
SamsungAdapter({required this._transportClient, CommandKeyMap? keyMapper})
  : _keyMapper = keyMapper ?? const SamsungKeyMapper();
```

(The named constructor argument at call sites is `transportClient:`, not `_transportClient:`
— Dart drops the leading underscore from a field-formal parameter's external name even
though the field itself is private.)

That optional parameter is the seam this section uses. A variant adapter doesn't need to
supply a whole new `CommandKeyMap` implementation — it needs to supply the *same* mapper
with a *few entries swapped*.

### VariantKeyMap

A generic decorator over `CommandKeyMap`, already defined once in `command_key_map.dart`
(not something you write per variant) and reused across every brand and every variant:

```dart
class VariantKeyMap extends CommandKeyMap {
  const VariantKeyMap(this._base, this._overrides);
  final CommandKeyMap _base;
  final Map<RemoteCommand, CommandPayload> _overrides;

  @override
  CommandPayload? payloadFor(RemoteCommand command) =>
      _overrides[command] ?? _base.payloadFor(command);
}
```

`payloadFor` checks the override map first and falls through to the base mapper for every
command the variant doesn't touch. The base mapper's full command set stays live and
current automatically — if the brand's default mapper later adds support for a new
command, every variant built on `VariantKeyMap` picks it up for free, with zero edits.
`TclGoogleTvAdapter` is a real, live example of this pattern — it composes
`VariantKeyMap(AndroidTvKeyMapper(), _tclLegacyAppLinkOverrides)` to keep the legacy
`market://launch?id=...` app-link scheme for four commands while inheriting everything
else from `AndroidTvKeyMapper` unchanged (`tcl_google_tv_adapter.dart:17-35`).

---

## Step-by-step: diverging one command for a variant

The example below gives a hypothetical `Samsung Frame` variant (per the example already
used in `guide-protocol-variants.md`) a region-specific Disney+ app id, while leaving
every other Samsung command mapping untouched.

### Step 1 — Confirm the variant already exists

Verify the variant's constant, predicate, and registry entry are already in place per
`guide-protocol-variants.md`'s checklist:

```dart
// samsung_protocol_variants.dart
abstract final class SamsungProtocolVariants {
  static const String defaultVariant = TvDevice.defaultProtocolVariant;
  static const String frameVariant = 'samsung_frame';
  static bool isFrameSeries(TvDeviceInfo info) { ... }
}
```

If it doesn't exist yet, create it there first — this section only covers what the variant's
adapter does once it can already be resolved and routed to.

### Step 2 — Build the override map

Identify exactly which `RemoteCommand`s the variant needs to differ on, and write only
those as a `Map<RemoteCommand, CommandPayload>`. Do not re-list commands that are unchanged
— that's what `VariantKeyMap`'s fallback to `_base` is for.

```dart
const _frameOverrides = <RemoteCommand, CommandPayload>{
  RemoteCommand.disneyPlus: AppLink('region-specific-disney-app-id'),
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
          RemoteCommand.disneyPlus: AppLink('region-specific-disney-app-id'),
        }),
      );

  @override
  String get protocolVariant => SamsungProtocolVariants.frameVariant;
}
```

That's the entire class. No transport calls, no pairing logic, no connection-state
plumbing — all of it comes from `SamsungAdapter` unchanged.

### Step 4 — Register the adapter in DI

This is the same DI step `guide-protocol-variants.md` already documents — nothing
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
  localizedStrings: sl<LocalizedStrings>(),
  identityRegistry: sl<DeviceIdentityRegistry>(),
);
```

---

## Checklist

- [ ] Confirmed the protocol variant already exists per `guide-protocol-variants.md` (constant, predicate, registry entry)
- [ ] Identified exactly which `RemoteCommand`s diverge for this variant — no unchanged commands re-listed in the override map
- [ ] Variant adapter class **extends** the brand's existing adapter (not `TvBrandAdapter` directly)
- [ ] Adapter overrides only `protocolVariant` and composes a `VariantKeyMap` through the base adapter's `keyMapper` constructor parameter
- [ ] Adapter registered in DI config alongside the brand's default adapter, per `guide-protocol-variants.md`'s Step 3/DI registration
- [ ] If the variant also adds or removes which commands are supported (not just their payload), `supportedCommands` is explicitly overridden in the same subclass
- [ ] Test: `payloadFor` returns the overridden payload for the diverging command(s)
- [ ] Test: `payloadFor` falls through to the base mapper's payload for every non-overridden command
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
`(brand, protocolVariant)` (`brand_routed_remote_command_service.dart:20`), so the adapter
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
`samsung_adapter.dart:55`). If a variant genuinely supports a different command set than
its brand's default — not just different payloads for the same commands — override
`supportedCommands` explicitly in the same adapter subclass. There is no automatic
mechanism today that keeps `supportedCommands` and the key-map overrides in sync; that's a
manual responsibility of whoever writes the variant adapter.

---

## Adding a brand-specific payload type

`VidaaLaunch` exists because Hisense's `launchVidaaApp` genuinely needs two named pieces of data
that don't fit `AppLink`'s single `uri` field. Before adding another subclass like it, check
whether the new brand's transport method can actually be expressed as an existing subclass —
most "this brand is different" instincts turn out to be a `KeySequence` with an unusual string
format (still just one code to send via `sendKey`) rather than a genuinely new transport method.
Only add a new `CommandPayload` subclass when there's a real new method on the transport client
it corresponds to. Adding it doesn't force every other adapter's `sendCommand` to change — their
`default:` case already covers it — so nothing will tell you if the brand you actually meant to
support it on forgot a real `case` for it except `supported_commands_dispatch_test.dart`. See
"Why `sealed`, and why `default:`" above.

---

## Testing

`payloadFor` is directly assertable without constructing an adapter or a transport client:

```dart
test('netflix resolves to the Tizen app id as an AppLink', () {
  const mapper = SamsungKeyMapper();
  expect(mapper.payloadFor(RemoteCommand.netflix), const AppLink('3201907018807'));
});
```

Compare this to testing Samsung's old `LAUNCH:`-prefix convention, which required the test to
hardcode the exact sentinel string (`'LAUNCH:3201907018807'`) and knowledge of where it got
parsed — `payloadFor` needs neither.
