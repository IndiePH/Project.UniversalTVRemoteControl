# Goal: LG Remote Command Convention Consolidation

**Branch:** `refactor/lg-remote-command-convention-consolidation` (planned; not yet created)
**Status:** proposed — planning only, not yet approved for implementation. Nothing in `lib/`
has been touched to produce this document.
**Related:** `references/goals/goal-app-launch-dispatch-unification.md` — the original
`CommandPayload` migration. That migration finished for every adapter except LG: LG's
app-launch commands were deliberately left on the old sentinel convention (see that goal doc's
Phase 3), and its `POINTER:`/`TOGGLE:` sentinels were explicitly out of scope for that phase.
This goal finishes what that one left unfinished, for LG only. See also
`references/guide-remote-command-dispatch.md`, the live contract this goal extends.
**Origin:** surfaced while auditing `guide-remote-command-dispatch.md`'s note that "LG still
uses a sentinel" for app-launch — closer inspection of `LgWebSocketTransportClient` found the
sentinel convention is broader than just app-launch: four more behaviors use the same trick.

> ⚠️ **Not verified or approved by the user beyond an initial "yes, draft a plan."** Every claim
> under "Verified facts" was confirmed by direct source reads (file:line cited) on 2026-08-25.
> "Proposed target design" and the phased plan are unevaluated proposals, not decisions.

---

## Problem statement

`CommandPayload`'s whole premise — "the payload's *type* says how to dispatch it, not its
string content" — holds for every adapter except LG. `LgWebSocketTransportClient`'s command
factory still parses the string inside `KeySequence.codes` to decide whether to do a normal SSAP
key send, a pointer-socket write, a launcher call, or a stateful toggle. Five distinct
behaviors are smuggled through one `List<String>` slot via sentinel prefixes or exact-string
matches, sniffed with `startsWith`/`==` at dispatch time — precisely the SRP leak the original
`CommandPayload` migration eliminated everywhere else.

## Verified facts (direct source reads, 2026-08-25)

1. **`_LgCommandFactory.getCommand`** (`lib/remote_control/data/adapters/lg/lg_websocket_transport_client.dart:704-780`)
   branches on the string content of `keyCode` five ways before falling through to a plain SSAP
   send:
   - `keyCode.startsWith(lgPointerPrefix)` (`:710-715`) → `_client._sendPointerCommand(deviceId:, button:)`, where `button` is the substring after `'POINTER:'`.
   - `keyCode.startsWith(lgLaunchPrefix)` (`:716-725`) → `_client._sendSsap(uri: 'ssap://system.launcher/launch', payload: {'id': appId})`, where `appId` is the substring after `'LAUNCH:'`. This is exactly what `AppLink` already models for every other brand.
   - `keyCode == 'ssap://audio/setMute'` (`:726-739`) → flips `_remoteStates[deviceId][_RemoteStateKey.mute]` and sends the mute SSAP call with the new value. Note this branch is matched on the **literal real SSAP URI**, not a synthetic sentinel constant — the only one of the five that isn't.
   - `keyCode == lgPowerToggleKey` (`'TOGGLE:POWER'`, `:740-754`) → flips `_remoteStates[deviceId][_RemoteStateKey.power]`, sends `ssap://system/turnOn` or `ssap://system/turnOff`.
   - `keyCode == lgPlayPauseToggleKey` (`'TOGGLE:PLAY_PAUSE'`, `:755-771`) → flips `_remoteStates[deviceId][_RemoteStateKey.playing]`, sends `ssap://media.controls/play` or `ssap://media.controls/pause`.
   - Fallback (`:772-778`): `_client._sendSsap(uri: keyCode, payload: {})` — the plain case, where the string genuinely *is* the transport payload. This one is not a problem; a `KeySequence` code that's used as-is, not sniffed for hidden meaning, is exactly what `KeySequence` is for.
2. **The sentinel constants live in the key mapper, not the transport client**
   (`lg_key_mapper.dart:7,19,22,25`): `lgPointerPrefix = 'POINTER:'`, `lgLaunchPrefix =
   'LAUNCH:'`, `lgPowerToggleKey = 'TOGGLE:POWER'`, `lgPlayPauseToggleKey = 'TOGGLE:PLAY_PAUSE'`.
   The mute case has no such constant — `'ssap://audio/setMute'` is matched directly.
3. **`_RemoteStateKey`** (`lg_websocket_transport_client.dart:694`) is already a private enum
   with exactly the three toggle kinds: `enum _RemoteStateKey { mute, power, playing }`. The
   per-device state map (`_remoteStates`, `:82`) already exists and is reused across all three
   toggle branches.
4. **`LgTransportClient`** (`lg_transport_client.dart:6-46`) declares only `sendKey` as its
   command-dispatch method — no `sendPointerCommand`, no toggle method, no `sendAppLink`.
   `_sendSsap` (`:301-325`) and `_sendPointerCommand` (`:360-374`) are private methods on the
   concrete `LgWebSocketTransportClient`, reachable today only by round-tripping through
   `sendKey` → `_commandFactory.getCommand(...).execute()` (`:203`) and string-sniffing the
   result back out.
5. **`LgAdapter.sendCommand` already throws for the payload types LG doesn't use**
   (`lg_adapter.dart:88-107`): the `AppLink` and `VidaaLaunch` cases both throw
   `UnsupportedError` today, confirming LG's key mapper genuinely never returns those types —
   consistent with `guide-remote-command-dispatch.md`'s note that LG kept `KeySequence`
   everywhere on purpose.
6. **`TransportCommandFactory`/`TransportCommand`** (`lib/remote_control/data/adapters/transport_command.dart`)
   is an LG-only abstraction — repo-wide grep found no other adapter implementing or
   referencing it. `_LgCommandFactory`/`_LgTransportCommand` are its only implementations.
7. **Migration surface:** 9 classes implement `LgTransportClient` and would need any new
   interface method added by hand (`implements`, not `extends`, so no default body is
   inherited) — `FakeLgTransportClient` (`lib/remote_control/debug/fake_lg_transport_client.dart:13-15`)
   plus 8 test-local fakes in `test/lib/remote_control/data/adapters/lg_test_lane_test.dart`
   (`_SlowLgTransportClient`, `_TimeoutLgTransportClient`, `_ErrorOnSendLgTransportClient`,
   `_ReconnectTrackingLgTransportClient`, `_ImeRejectingLgTransportClient`,
   `_ClearPairingTrackingLgTransportClient`, `_TextInputReadyLgTransportClient`,
   `_StaleKeyLgTransportClient`). Separately, `test/lib/remote_control/data/adapters/lg/lg_key_mapper_test.dart`
   asserts directly on `KeySequence([lgPointerPrefix...])`/`lgPowerToggleKey`/`lgLaunchPrefix`
   sentinel strings and would need rewriting to assert on the new payload types instead.

## Proposed target design

Reuse `AppLink` for the launch case (as the original migration always intended for LG, per
`goal-app-launch-dispatch-unification.md`'s Phase 3 — just never executed). Add two new
`CommandPayload` subclasses for the two genuinely new transport methods this uncovers:

```dart
/// Dispatched via a new LgTransportClient.sendPointerCommand. Carries the raw pointer-socket
/// button name with no prefix to parse.
final class PointerCommand extends CommandPayload {
  const PointerCommand(this.button);
  final String button;
}

/// Dispatched via a new LgTransportClient.sendToggle. [kind] replaces today's three duplicated
/// "flip tracked state, compute the SSAP call" branches with one parameterized method.
enum LgToggleKind { power, playPause, mute }

final class ToggleCommand extends CommandPayload {
  const ToggleCommand(this.kind);
  final LgToggleKind kind;
}
```

(Whether `PointerCommand`/`ToggleCommand` belong in the shared `command_key_map.dart` sealed
hierarchy alongside `KeySequence`/`AppLink`/`VidaaLaunch`, or in an LG-specific extension of it,
is an open question below — `CommandPayload` is `sealed`, so every adapter's `sendCommand`
switch must be updated regardless of where the subclasses live.)

`LgAdapter.sendCommand`'s switch gains two real cases in place of today's two `throw`/missing
cases:

```dart
switch (payload) {
  case KeySequence(:final codes):
    for (final code in codes) {
      await _transportClient.sendKey(deviceId: device.id, keyCode: code);
    }
  case AppLink(:final uri):
    await _transportClient.sendAppLink(deviceId: device.id, appLink: uri);
  case PointerCommand(:final button):
    await _transportClient.sendPointerCommand(deviceId: device.id, button: button);
  case ToggleCommand(:final kind):
    await _transportClient.sendToggle(deviceId: device.id, kind: kind);
  case VidaaLaunch():
    throw UnsupportedError('LG has no VidaaLaunch dispatch path.');
}
```

`LgWebSocketTransportClient.sendToggle(deviceId:, kind:)` replaces the three duplicated
toggle branches with one method, switching on `kind` to pick the state key and the two
candidate SSAP URIs — the state-flip logic itself (read `_remoteStates`, negate, write back,
send) doesn't change, only where it's reached from. `sendPointerCommand` and `sendAppLink`
(wrapping today's `_sendSsap('ssap://system.launcher/launch', ...)` call) get promoted from
private to real `LgTransportClient` interface methods, the same way `SamsungWebSocketTransportClient.launchApp`
was promoted during the original migration.

Once all five special cases are reached directly from `LgAdapter.sendCommand` instead of via
`sendKey` → `_commandFactory.getCommand(...).execute()`, `_LgCommandFactory`/`_LgTransportCommand`
have nothing left to do except the plain fallback — `sendKey` can call
`_sendSsap(uri: keyCode, payload: {})` directly, and the whole `TransportCommandFactory`
abstraction (Verified fact 6, LG-only, unused elsewhere) likely becomes deletable. Confirm this
during implementation rather than committing to it here.

## Tradeoffs (honest accounting, not oversold)

- **Real transport-layer work, not a doc-only or pure-rename change.** Two new public interface
  methods on `LgTransportClient`, one new private-to-public promotion, and the toggle
  state-flip logic relocating from an inline command-factory branch to a named method. The
  underlying SSAP calls and state semantics are unchanged — this is a dispatch-path
  reorganization, not a behavior change — but it touches real transport code, unlike the
  mechanical `KeySequence([...])`-wrapping phases of the original migration.
- **Every `LgTransportClient` fake needs updating.** 9 implementers (Verified fact 7), all via
  `implements`, none inheriting a default body. This is a larger blast radius than any single
  phase of the original migration (Samsung's `AppLink` addition touched 5 fakes).
- **One test file needs a rewrite, not just new assertions.** `lg_key_mapper_test.dart`'s
  existing tests assert on sentinel-string `KeySequence` values; those tests describe behavior
  that will no longer exist once the sentinels are removed, so they get replaced (asserting
  `PointerCommand`/`ToggleCommand`/`AppLink` instead), not extended.
- **Risk: LOW-MEDIUM.** No SSAP wire format changes, no state-semantics changes, and the
  pattern (promote a private method to the interface, reuse an existing `CommandPayload`
  subclass or add a narrowly-scoped new one) is proven by the original migration. The risk is
  entirely in surface area (9 fakes, 1 rewritten test file, 2 new interface methods), not in
  design uncertainty.

## Phased plan

**Phase 1 — Transport interface additions.**
**Status:** proposed. **Risk:** LOW.
- Add `sendPointerCommand(deviceId:, button:)` and `sendToggle(deviceId:, kind:)` to
  `LgTransportClient`; add `sendAppLink(deviceId:, appLink:)` (or promote `_sendSsap`'s launch
  call under that name) alongside them.
- Implement all three on `LgWebSocketTransportClient` by extracting today's existing branch
  bodies verbatim — `sendToggle` in particular should read as the three duplicated
  power/playPause/mute blocks collapsed into one `switch (kind)`.
- Update all 9 `LgTransportClient` implementers (Verified fact 7) with the new methods.

**Phase 2 — `CommandPayload` and key mapper.**
**Status:** proposed. **Risk:** LOW. **Deps:** none (independent of Phase 1's transport work,
but should land after it so the payload types have somewhere real to dispatch to).
- Add `PointerCommand`/`ToggleCommand`/`LgToggleKind` (placement TBD, see Open questions).
- Change `LgKeyMapper`'s pointer/launch/toggle entries from sentinel-prefixed `KeySequence` to
  `PointerCommand`/`AppLink`/`ToggleCommand` respectively; delete `lgPointerPrefix`,
  `lgLaunchPrefix`, `lgPowerToggleKey`, `lgPlayPauseToggleKey`.
- Rewrite `lg_key_mapper_test.dart` to assert the new payload types.

**Phase 3 — Adapter dispatch.**
**Status:** proposed. **Risk:** LOW. **Deps:** Phases 1-2.
- Update `LgAdapter.sendCommand`'s switch per "Proposed target design" above.
- Confirm `LgAdapter.supportedCommands`'s existing `payloadFor(c) != null` derivation needs no
  change (it shouldn't — the set of supported commands doesn't change, only how each payload's
  type is spelled).

**Phase 4 — Remove the string-sniffing command factory.**
**Status:** proposed. **Risk:** LOW. **Deps:** Phases 1-3 (all five special cases must be
reachable without going through `sendKey` first).
- Delete `_LgCommandFactory`/`_LgTransportCommand`'s five branches; `sendKey` calls
  `_sendSsap(uri: keyCode, payload: {})` directly for the plain case.
- If nothing else needs `TransportCommandFactory`/`TransportCommand` (Verified fact 6), delete
  those interfaces too.

## Open questions

1. **Where do `PointerCommand`/`ToggleCommand`/`LgToggleKind` live?** In the shared
   `command_key_map.dart` sealed hierarchy (alongside `KeySequence`/`AppLink`/`VidaaLaunch`), or
   in an LG-specific file that extends the same `sealed class CommandPayload`? Either is legal
   Dart (a `sealed` class only requires all direct subtypes to be in the same library — need to
   confirm `command_key_map.dart` is the right library boundary, or whether these need to live
   in the same file to satisfy the sealed-class constraint). Affects whether every other
   adapter's exhaustive `sendCommand` switch is forced to add `case PointerCommand():` /
   `case ToggleCommand():` branches (likely `throw UnsupportedError`, matching the existing
   `VidaaLaunch`-on-non-Hisense pattern) even though only LG ever produces them.
2. **Does `sendAppLink` reuse the name already used by `AndroidTvTransportClient`/`TclRoku`'s
   `launchApp`, or get an LG-specific name?** The transport call itself is LG-specific
   (`ssap://system.launcher/launch`), but the `CommandPayload` case (`AppLink`) is shared —
   worth deciding whether `LgTransportClient`'s method name should match
   `AndroidTvTransportClient.sendAppLink`'s naming for consistency, even though the two are
   unrelated interfaces.
3. **Is the mute case's lack of a named sentinel constant (Verified fact 1) worth normalizing
   before removal**, or does it not matter once the whole branch is deleted in Phase 4 anyway?
   Leaning toward "doesn't matter" — noting it here so it isn't rediscovered as a surprise
   mid-implementation.
