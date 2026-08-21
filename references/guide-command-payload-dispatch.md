# Guide: The `CommandPayload` Dispatch Contract

> ⚠️ **Status: describes a proposed design, not the current codebase.** Today,
> `CommandKeyMap.keyCodesFor(RemoteCommand) -> List<String>` is the live contract — see
> `guide-adding-diverging-remote-commands.md` for how to work with it as it exists right now.
> This guide documents the target shape proposed in
> `references/goals/goal-app-launch-dispatch-unification.md`: nothing in `lib/` implements
> `CommandPayload` or `payloadFor` yet. Once that goal doc's Phase 0 lands, this guide describes
> the real contract; until then, treat every code sample below as a worked example of the
> destination, not a description of what exists.

## Why this exists

Today, five brands each dispatch "app-launch" commands (Netflix, Disney+, Prime Video, YouTube,
web) through a different mechanism: Samsung/LG hide a `LAUNCH:`-prefixed sentinel string inside
the key mapper and let the *transport client* `startsWith`-sniff it; AndroidTv/TclGoogleTv keep
a second map on the adapter, checked before the keymapper; Hisense keeps a tuple-returning
switch on the adapter with the keymapper deliberately left empty for those commands. Three
different shapes for the same underlying idea: "this command doesn't send a raw key code, it
launches an app, and needs different data and a different transport call to do it."

`CommandPayload` collapses those three shapes into one: every command's dispatch information
— both the data to send and *how* to send it — lives in exactly one place, the key map.

## The contract

```dart
sealed class CommandPayload {
  const CommandPayload();
}

/// Dispatched via `sendKey`. One or more ordered fallback key-code aliases to try in order —
/// the same meaning `keyCodesFor`'s `List<String>` already carries today.
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
wins, exactly like `keyCodesFor`'s existing fallback-list behavior):

```dart
RemoteCommand.back: const KeySequence(['KEY_RETURNS', 'KEY_RETURN', 'KEY_BACK']),
```

An app-launch command — note there's no prefix, no sentinel, nothing to parse downstream:

```dart
RemoteCommand.netflix: const AppLink('market://launch?id=com.netflix.ninja'),
```

A command this brand/variant doesn't support at all — omit the entry; `payloadFor` returns
`null` for any key missing from the underlying map, exactly like `keyCodesFor` returns `[]`
today.

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

Compare this to testing the current `LAUNCH:`-prefix convention, which requires the test to
hardcode the exact sentinel string (`'LAUNCH:3201907018807'`) and knowledge of where it gets
parsed — `payloadFor` needs neither.
