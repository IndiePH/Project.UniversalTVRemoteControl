# Guide: The `CommandPayload` Dispatch Contract

> **Status: this is the live contract.** `CommandKeyMap.payloadFor(RemoteCommand) ->
> CommandPayload?` (`lib/remote_control/data/adapters/command_key_map.dart`) is what every
> adapter — Samsung, LG, AndroidTv, TclGoogleTv, TclRoku, TclLegacyWifi, Hisense, Sony — uses
> today. There is no `keyCodesFor`/`List<String>` contract left anywhere in `lib/`; it was fully
> replaced by this one. `references/goals/goal-app-launch-dispatch-unification.md` is the
> historical planning record for how this migration was designed — useful for the reasoning
> behind specific choices (e.g. why LG still uses a sentinel, below), but its own status banner
> and phase markers still say "proposed," which is stale — verify against the code, not that
> doc's banner, if you need to know what's actually built.

## Why this exists

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
`VariantKeyMap` for TclGoogleTv's `market://` override — see
"Diverging one command for a variant" below); TclRoku's `_appIds` map is gone the same way
(`TclRokuKeyMapper`'s four launch commands are now plain `AppLink` entries carrying Roku channel
ids); Hisense's keymapper carries real `VidaaLaunch` entries instead of being left empty. The
one deliberate holdout is LG: its app-launch commands
still dispatch as a `KeySequence` carrying a `LAUNCH:`-prefixed string, sniffed by
`LgWebSocketTransportClient` — not a leftover, but a scope decision (see "Adding a
brand-specific payload type" below for why a brand keeping a sentinel doesn't need a new
`CommandPayload` subclass).

## The contract

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
a genuinely new transport method needs data no existing subclass can carry (see below).

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

## Writing `sendCommand`

Every adapter's `sendCommand` becomes the same shape — one exhaustive switch over what the key
map returns:

```dart
@override
Future<void> sendCommand({
  required TvDevice device,
  required RemoteCommand command,
}) async {
  await _transportClient.connect(deviceId: device.id);
  switch (_keyMap.payloadFor(command)) {
    case null:
      throw UnsupportedError('No mapping for command: $command');
    case KeySequence(:final codes):
      for (final code in codes) {
        await _transportClient.sendKey(deviceId: device.id, keyCode: code);
      }
    case AppLink(:final uri):
      await _transportClient.sendAppLink(deviceId: device.id, appLink: uri);
    case VidaaLaunch(:final displayName, :final url):
      await _transportClient.launchVidaaApp(
        deviceId: device.id,
        displayName: displayName,
        url: url,
      );
  }
}
```

Because `CommandPayload` is `sealed`, this `switch` is exhaustiveness-checked by the compiler.
If a new subclass is ever added and a brand's `sendCommand` doesn't handle it, that adapter
fails to compile — not silently drops the command at runtime.

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

## Diverging one command for a variant

This doesn't change how `guide-adding-diverging-remote-commands.md`'s `VariantKeyMap` decorator
works conceptually — it still wraps a base key map plus an override map, falling through for
anything not overridden. Only the method name and return type change:

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

A region-specific Disney+ app id for a hypothetical Samsung Frame variant:

```dart
const _frameOverrides = <RemoteCommand, CommandPayload>{
  RemoteCommand.disneyPlus: AppLink('region-specific-disney-app-id'),
};
```

Everything else in that guide's checklist — one adapter subclass per variant, `protocolVariant`
override, DI registration — is unaffected by this contract change.

## Adding a brand-specific payload type

`VidaaLaunch` exists because Hisense's `launchVidaaApp` genuinely needs two named pieces of data
that don't fit `AppLink`'s single `uri` field. Before adding another subclass like it, check
whether the new brand's transport method can actually be expressed as an existing subclass —
most "this brand is different" instincts turn out to be a `KeySequence` with an unusual string
format (still just one code to send via `sendKey`) rather than a genuinely new transport method.
Only add a new `CommandPayload` subclass when there's a real new method on the transport client
it corresponds to, and update every adapter's `sendCommand` switch to handle it — the compiler
will tell you which ones you missed.

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
