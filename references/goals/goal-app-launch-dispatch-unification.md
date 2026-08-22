# Goal: App-Launch Dispatch Unification

**Branch:** `refactor/command-and-adapters` (current; originally drafted on
`feature/command-drawer`, which has since merged into `main`)
**Status:** proposed — planning only, not yet approved for implementation. **Design revised
2026-08-21**, same day as the original draft: the dispatch mechanism changed from a
`Set<RemoteCommand>` marker to a sealed `CommandPayload` return type (see "Proposed target
design"). The problem statement and verified facts below are unchanged by the revision.
**Related:** none of the other `references/goals/` docs touch this surface directly; this is
an independent adapter/keymapper-layer cleanup, not coupled to the layout/drawer work. See also
`references/guide-command-payload-dispatch.md`, an implementation-guide companion to this
document describing the target `CommandPayload` contract in worked-example form.
**Origin:** surfaced during a design review of how `RemoteCommand.netflix` / `.primeVideo` /
`.disneyPlus` / `.youtube` / `.web` ("app-launch commands") are dispatched across the seven
`TvBrandAdapter` implementations.

> ⚠️ **This document has not been verified or approved by the user beyond an initial lean
> toward the direction below.** Every claim under "Verified facts" was confirmed by direct
> source reads (file:line cited) as of 2026-08-21. "Proposed target design" and the phased
> plan are unevaluated proposals, not decisions. Nothing in `lib/` has been touched to
> produce this document. The user reviewed and preferred the `CommandPayload` design over the
> original `appLinkCommands` sketch on 2026-08-21 — a stronger signal than the initial lean
> noted above, but still not sign-off to begin implementation.

---

## Problem statement

App-launch commands are dispatched through **four different, inconsistent mechanisms**
across the six adapters that support them (`SamsungAdapter`, `LgAdapter`, `AndroidTvAdapter`,
`TclGoogleTvAdapter`, `TclRokuAdapter`, `HisenseAdapter` — `TclLegacyWifiAdapter` supports none
of these five commands and is out of scope, see Verified fact 6). This is a real SRP/DRY
problem, not a cosmetic one: one mechanism leaks a business-logic string convention into the
transport layer, and two adapters carry a byte-for-byte duplicated map.

## Verified facts (direct source reads, 2026-08-21)

1. **Samsung/LG embed a `LAUNCH:`-prefixed sentinel string inside the key mapper, and the
   *transport client* is what notices it.**
   - `SamsungKeyMapper._commandToKeyCodes` (`lib/remote_control/data/adapters/samsung/samsung_key_mapper.dart:19-31`)
     maps `.web`/`.netflix`/`.primeVideo`/`.disneyPlus`/`.youtube` to
     `'$samsungLaunchPrefix${SamsungTizenAppIds.<id>}'` — e.g. `'LAUNCH:3201907018807'` for
     Netflix. `samsungLaunchPrefix` (`'LAUNCH:'`) and `SamsungTizenAppIds` live in
     `lib/remote_control/data/adapters/samsung/samsung_app_launch.dart:5,10-16`.
   - `SamsungAdapter.sendCommand` (`samsung_adapter.dart:103-116`) loops
     `_keyMapper.keyCodesFor(command)` uniformly through `_transportClient.sendKey(...)` for
     *every* command — it has no idea some of those strings are launch sentinels.
   - `SamsungWebSocketTransportClient.sendKey` (`samsung_websocket_transport_client.dart:259-268`)
     is what actually branches: `if (keyCode.startsWith(samsungLaunchPrefix)) { ...
     launchApp(...); return; }` before falling through to the normal `SendRemoteKey` payload.
     A "bytes over the wire" component has to parse a business-logic string convention to do
     this — the SRP leak the background review flagged.
   - LG is structurally identical: `LgKeyMapper._kLgCommandMap`
     (`lib/remote_control/data/adapters/lg/lg_key_mapper.dart:43-47`) maps the five commands to
     `'${lgLaunchPrefix}<appId>'` (e.g. `'LAUNCH:netflix'`); `LgAdapter.sendCommand`
     (`lg_adapter.dart:86-98`) loops uniformly through `_transportClient.sendKey`;
     `_LgCommandFactory.getCommand` (`lg_websocket_transport_client.dart:708-725`, reached via
     `LgWebSocketTransportClient.sendKey` at `:201-203`) is what actually inspects
     `keyCode.startsWith(lgLaunchPrefix)` and issues `ssap://system.launcher/launch` instead.
   - **LG already uses this exact sentinel-prefix trick for two other things**, confirmed in
     the same file: `lgPointerPrefix` (`'POINTER:'`, `lg_key_mapper.dart:7`, branched at
     `lg_websocket_transport_client.dart:710-715`) for pointer-socket input, and toggle
     sentinels `lgPowerToggleKey`/`lgPlayPauseToggleKey` (`'TOGGLE:POWER'`/`'TOGGLE:PLAY_PAUSE'`,
     `lg_key_mapper.dart:14,17`, branched at `lg_websocket_transport_client.dart:740,755`). LG's
     `keyCodesFor` already returns non-literal-key-code opaque strings today for reasons beyond
     app launch — relevant context for the naming question in Open questions below.

2. **AndroidTv/TclGoogleTv use a separate adapter-level map, checked before the keymapper.**
   - `AndroidTvAdapter._appLinks` (`android_tv_adapter.dart:66-72`) and
     `TclGoogleTvAdapter._appLinks` (`tcl_google_tv_adapter.dart:22-28`) are **byte-for-byte
     identical** `Map<RemoteCommand, String>` literals (netflix/primeVideo/disneyPlus/youtube →
     `market://launch?id=...` URIs). Both adapters also default their `CommandKeyMap` to the
     **same** `AndroidTvKeyMapper` class (`android_tv_adapter.dart:15`,
     `tcl_google_tv_adapter.dart:15`) — this is a live, real duplication, independent of
     anything else in this doc.
   - `sendCommand` in both adapters (`android_tv_adapter.dart:74-92`,
     `tcl_google_tv_adapter.dart:80-99`) checks `_appLinks[command]` first and calls
     `_transportClient.sendAppLink(deviceId:, appLink:)` (interface at
     `android_tv/android_tv_transport_client.dart:19`) before falling through to the keymapper
     `sendKey` loop. Folding the app-link payloads into `AndroidTvKeyMapper` deletes the
     duplicated map in both adapters for free.

3. **TclRoku uses the same shape as #2, one adapter, own keymapper.**
   `TclRokuAdapter._appIds` (`tcl_roku_adapter.dart:18-23`) maps the four launchable commands
   (no `.web` — Roku has no browser command) to Roku channel ids (e.g. `'12'` for Netflix).
   `sendCommand` (`:92-108`) checks `_appIds[command]` first, calling
   `_transportClient.launchApp(deviceId:, appId:)` (interface at `tcl/roku_transport_client.dart:11`)
   before the keymapper's `primaryKeyCodeFor` path. `TclRokuAdapter.supportedCommands`
   (`:57-58`) is **not** the shared `kCommonSupportedRemoteCommands` constant — it returns a
   hand-rolled `_supportedCommands` set (`:25-46`) that already correctly excludes
   `RemoteCommand.web`.

4. **Hisense uses a `(String, String)?` tuple-returning switch, not a single string.**
   `HisenseAdapter._vidaaLaunchSpec` (`hisense_adapter.dart:152-163`) returns
   `(displayName, url)` for the five app-launch commands (e.g. `('Netflix', 'netflix')`) and
   `null` otherwise; `sendCommand` (`:90-119`) checks it first and calls
   `_transportClient.launchVidaaApp(deviceId:, displayName:, url:)` (interface at
   `hisense/hisense_transport_client.dart:24`). `HisenseKeyMapper` explicitly maps all five
   commands to `[]` (`hisense_key_mapper.dart:35-41`), with an existing comment: "Handled via
   launch-app MQTT, not sendkey." **Noted anomaly, not in scope to fix here:**
   `_vidaaLaunchSpec`'s `RemoteCommand.web` case returns `('YouTube', 'youtube')` — the same
   tuple as `.youtube` — rather than a browser spec; flagging since an accurate migration of
   this switch into a keymap payload must decide whether to preserve or fix this behavior
   (see Phase 4).

5. **`kCommonSupportedRemoteCommands`** (`supported_remote_commands.dart:4-26`) is the full
   21-value `RemoteCommand` enum and includes all five app-launch commands. **Superseded as of
   2026-08-21, same day:** at the time this fact was first recorded, Samsung, LG, AndroidTv,
   TclGoogleTv, and Hisense all returned this constant unchanged from `supportedCommands`. That
   has since changed (ahead of, and independent from, this document's phased plan) — see the
   Phase 5 interim note below for the current state of each adapter's `supportedCommands`.

6. **`TclLegacyWifiAdapter` is out of scope.** Its `_supportedCommands` set
   (`tcl_legacy_wifi_adapter.dart:19-36`) contains zero app-shortcut commands — no branch of
   this migration touches it.

7. **`CommandKeyMap`** (`lib/remote_control/data/adapters/command_key_map.dart:4-16`) is the
   shared abstraction: `List<String> keyCodesFor(RemoteCommand)` plus a derived
   `primaryKeyCodeFor` (first element or `null`). Today `keyCodesFor`'s return value means
   "ordered list of fallback key-code aliases to try" for every adapter except the app-launch
   commands on Samsung/LG (where it's actually a single opaque sentinel string) and Hisense
   (where it's always `[]` for these five commands, meaning "not handled this way").

## Proposed target design

**Revised 2026-08-21.** The first draft of this section (preserved below in a collapsed note)
sketched a `Set<RemoteCommand> appLinkCommands` marker checked alongside the keymap. A same-day
follow-up design review replaced it with the design below: instead of adding a second
collection next to the keymap, `CommandKeyMap`'s core method changes shape so that the payload
*and* the dispatch decision are the same value — there is nothing left to keep in sync.

`CommandKeyMap.keyCodesFor(RemoteCommand) -> List<String>` becomes
`CommandKeyMap.payloadFor(RemoteCommand) -> CommandPayload?` (`null` = not supported).
`CommandPayload` is a sealed type with exactly one subclass per **transport method** — not per
data shape:

```dart
sealed class CommandPayload {
  const CommandPayload();
}

/// Dispatched via `sendKey`. One or more ordered fallback aliases — the same meaning
/// `keyCodesFor`'s `List<String>` already carries today for every non-app-launch command.
final class KeySequence extends CommandPayload {
  const KeySequence(this.codes);
  final List<String> codes;
}

/// Dispatched via `sendAppLink`/`launchApp`. Carries the raw app id or deep-link URI with no
/// sentinel prefix — the type itself signals "this is an app link," so nothing downstream
/// needs to parse a string convention to find that out.
final class AppLink extends CommandPayload {
  const AppLink(this.uri);
  final String uri;
}

/// Dispatched via `launchVidaaApp` (Hisense only). Directly resolves Open question 1 below:
/// the two pieces of data Hisense needs get named fields on their own type instead of being
/// force-fit into `List<String>`'s "ordered fallback aliases" meaning.
final class VidaaLaunch extends CommandPayload {
  const VidaaLaunch(this.displayName, this.url);
  final String displayName;
  final String url;
}
```

`sendCommand` becomes one exhaustive switch, identical in shape on every adapter (Dart's sealed
classes make this switch compiler-checked for exhaustiveness — a future new `CommandPayload`
subclass fails to compile at every `sendCommand` that doesn't handle it, instead of failing
silently at runtime):

```dart
Future<void> sendCommand({required TvDevice device, required RemoteCommand command}) async {
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

Concretely, per brand:
- **AndroidTv/TclGoogleTv:** `AndroidTvKeyMapper` gains four `AppLink('market://launch?id=...')`
  entries; both adapters' duplicate `_appLinks` maps are deleted; `sendAppLink` stays exactly
  as it is today (no transport change needed).
- **Samsung/LG:** the keymap's app-launch entries become `AppLink('<app id>')` — the `LAUNCH:`
  prefix is dropped entirely, since the payload's *type* now carries the dispatch decision, not
  its string contents. The transport clients still gain a real `sendAppLink`-equivalent method
  to replace the removed `startsWith` branch — this part is unchanged from the original design:
  `SamsungWebSocketTransportClient` already has `launchApp(deviceId:, appId:)` privately
  (`samsung_websocket_transport_client.dart:295`); it would become a proper public method
  called directly by the adapter instead of being reached via string-sniffing inside
  `sendKey`. LG's `_sendSsap(uri: 'ssap://system.launcher/launch', payload: {'id': appId})`
  call (`lg_websocket_transport_client.dart:719-723`) would similarly need a named,
  adapter-callable entry point.
- **TclRoku:** `TclRokuKeyMapper` gains four `AppLink('<roku channel id>')` entries; `_appIds`
  is deleted; `launchApp` stays as-is.
- **Hisense:** `HisenseKeyMapper`'s five commands become `VidaaLaunch(displayName, url)`
  entries, replacing `_vidaaLaunchSpec`'s switch cases one-for-one. This **unblocks** the
  original Phase 4 — Open question 1 no longer needs a separate decision; `VidaaLaunch` *is*
  the decision.
- **`TclLegacyWifiAdapter`:** has zero app-launch commands (Verified fact 6), but still
  implements `CommandKeyMap`, so its existing key-code constants need mechanical wrapping into
  `KeySequence([...])` to satisfy the new method signature — pure churn, no behavior change, no
  bug behind it. See Tradeoffs.

<details>
<summary>Superseded: original <code>appLinkCommands</code> sketch (kept for context, not a live alternative)</summary>

The original draft added a `Set<RemoteCommand> appLinkCommands` per adapter, checked before
calling `keyCodesFor`, instead of changing `CommandKeyMap`'s return type:

```dart
if (appLinkCommands.contains(command)) {
  final payload = _keyMap.keyCodesFor(command);
  await _transportClient.sendAppLink(deviceId: device.id, appLink: payload.single);
  return;
}
```

This works, but the `Set` and the keymap are two independent collections that must be kept in
sync by hand — a command listed in `appLinkCommands` but missing a keymap entry (or vice versa)
is a real, easy-to-make mistake this shape does not prevent. It is also why Hisense's tuple
problem (Open question 1) stayed unresolved in the original draft: nothing about the `Set`
design gives `keyCodesFor` a way to return two named pieces of data. The `CommandPayload`
design above removes the second collection entirely — the dispatch decision and the payload
are the same value, so they cannot disagree.

</details>

## Tradeoffs (honest accounting, not oversold)

- **OCP: no longer a wash, resolved by the revision.** The original `appLinkCommands`-Set
  sketch required touching two collections per new app-link command (the keymap entry and the
  `Set`) — see the superseded note above. The `CommandPayload` design removes that: adding a
  new app-link command touches exactly one entry, in one map, same as today's
  `_appLinks`/`_appIds` single-map edit — the difference is that entry now lives in the same
  map as every other command's payload instead of a separate one.
- **Real migration surface, larger than the original sketch, but mechanical.** Beyond the 5
  adapters, 4 keymapper classes (`SamsungKeyMapper`, `LgKeyMapper`, `AndroidTvKeyMapper` —
  shared by AndroidTv and TclGoogleTv, `TclRokuKeyMapper`), and the Samsung/LG transport
  clients already scoped in the original draft, changing `CommandKeyMap`'s core method
  signature touches every call site of `keyCodesFor` — roughly 66 across `lib/` and `test/`
  (repo-wide grep, verified 2026-08-21) — plus `TclLegacyWifiAdapter`, which has zero
  app-launch commands but still needs its existing constants mechanically wrapped in
  `KeySequence([...])` to satisfy the new signature. This is one-time, low-risk churn (a
  compiler-enforced find-and-wrap, not a logic change) rather than a design cost, but it is a
  wider blast radius than the original Set-based sketch, which only touched the 5 brands that
  actually dispatch app links. See "Phase 0" below, added by this revision specifically to
  isolate this mechanical step from the per-brand behavioral changes.
- **Naming: resolved as part of this revision, not deferred.** The original draft left
  "should `CommandKeyMap`/`keyCodesFor` be renamed" as an open question (Open question 2,
  below). This revision decides it: `keyCodesFor` becomes `payloadFor`, returning
  `CommandPayload?` instead of `List<String>`. The rename was going to be required regardless,
  since the return type is changing — deciding the name now avoids a second migration pass on
  the same call sites later. LG's `POINTER:`/`TOGGLE:` sentinels (Verified fact 1) are
  unaffected either way — they stay inside `KeySequence` strings, since they're a same-brand
  transport-routing concern this refactor doesn't touch.

## Phased plan

Ordered by confidence/risk, per the background discussion, plus a new Phase 0 added by the
2026-08-21 revision: because `CommandPayload` changes `CommandKeyMap`'s shared abstract method
signature, every concrete keymapper must implement the new method — unlike the original
`appLinkCommands` sketch (purely additive, so genuinely independent per brand), the interface
change itself is a one-time, all-keymappers step, not phaseable brand-by-brand. Splitting it
into its own zero-behavior-change phase keeps the rest of the plan's per-brand independence
intact for the *behavioral* changes (which app-launch payloads move to `AppLink`/`VidaaLaunch`
and which transport methods get called), while being honest that the interface migration
itself isn't divisible the way the original plan assumed.

**Phase 0 — `CommandKeyMap` interface migration (new in this revision).**
**Status:** proposed. **Risk:** LOW (mechanical, zero behavior change). **Deps:** none; must
land before Phases 1-4.
- Add `CommandPayload` (`KeySequence`/`AppLink`/`VidaaLaunch`) and the new
  `payloadFor(RemoteCommand) -> CommandPayload?` method to `CommandKeyMap`.
- Migrate all 6 concrete keymappers (`SamsungKeyMapper`, `LgKeyMapper`, `AndroidTvKeyMapper`,
  `TclRokuKeyMapper`, `HisenseKeyMapper`, `TclLegacyWifiKeyMapper` or equivalent) to implement
  `payloadFor`, wrapping every *existing* entry in `KeySequence([...])` unchanged — including
  Samsung/LG's `LAUNCH:`-prefixed strings and Hisense's `[]` entries, verbatim, with no
  behavior change yet. `AppLink`/`VidaaLaunch` are not used by any entry in this phase.
  `TclLegacyWifiAdapter`'s keymapper is included here even though it has zero app-launch
  commands (Verified fact 6) — it still implements the interface and needs the same wrap.
- Update every `keyCodesFor` call site (~66 across `lib/`+`test/`) to call `payloadFor` and
  pattern-match `KeySequence` out, or add a temporary `keyCodesFor` compatibility shim on
  `CommandKeyMap` derived from `payloadFor` if a fully atomic cutover isn't practical — this
  implementation-order decision is left to whoever picks up this phase.
- Remove `CommandKeyMap.keyCodesFor` and `primaryKeyCodeFor` (or update them to be derived
  from `payloadFor`, if kept for callers outside the adapters) once all call sites are
  migrated.

**Phase 1 — AndroidTv + TclGoogleTv.**
**Status:** proposed. **Risk:** LOW. **Deps:** Phase 0.
- Change `AndroidTvKeyMapper`'s four app-launch entries from absent/`[]` to
  `AppLink('market://launch?id=...')` (already shared by both adapters).
- Update `sendCommand` in both adapters to the unified switch shown in "Proposed target
  design"; delete both adapters' `_appLinks` maps.
- No transport-client change — `sendAppLink` is untouched.
- Update/extend any test that constructs or asserts against `_appLinks` directly.

**Phase 2 — TclRoku.**
**Status:** proposed. **Risk:** LOW. **Deps:** Phase 0 (independent of Phase 1).
- Change `TclRokuKeyMapper`'s four entries to `AppLink('<roku channel id>')`; delete `_appIds`.
- Update `sendCommand` to the unified switch.
- No transport-client change — `launchApp` is untouched.
- Confirm `TclRokuAdapter.supportedCommands`'s existing hand-rolled set is unaffected (it stays
  hand-rolled until Phase 5, same as the original plan).

**Phase 3 — Samsung + LG.**
**Status:** proposed. **Risk:** MEDIUM. **Deps:** Phase 0 (independent of Phases 1-2), but
should land after them so the pattern is proven on lower-risk brands first.
- Keymap entries change from `KeySequence(['LAUNCH:<id>'])` to `AppLink('<id>')` — the prefix
  is dropped entirely, not just relocated, since dispatch no longer depends on inspecting the
  string.
- Update `sendCommand` to the unified switch.
- Give each transport client a real, adapter-callable app-launch method
  (`SamsungWebSocketTransportClient.launchApp` promoted from private; LG needs an equivalent
  named entry point wrapping its existing `ssap://system.launcher/launch` call) and remove the
  `startsWith(samsungLaunchPrefix)` / `startsWith(lgLaunchPrefix)` branches from `sendKey`.
- LG's `POINTER:`/`TOGGLE:` sentinels are explicitly **not** touched by this phase — they stay
  inside `KeySequence` strings unchanged; only the `LAUNCH:` convention is being removed.
- Update every test asserting on the `LAUNCH:` prefix or the transport clients'
  `startsWith` branches.

**Phase 4 — Hisense.**
**Status:** proposed, **unblocked by this revision** (was blocked in the original draft).
**Risk:** LOW-MEDIUM, downgraded from MEDIUM-HIGH — `VidaaLaunch` resolves the payload-shape
question that previously blocked this phase. **Deps:** Phase 0.
- Change `HisenseKeyMapper`'s five `[]` entries to `VidaaLaunch(displayName, url)`, copied
  directly from `_vidaaLaunchSpec`'s existing switch cases (Verified fact 4); delete
  `_vidaaLaunchSpec`.
- Update `sendCommand` to the unified switch.
- Separately, decide (not as part of the mechanical migration) whether `RemoteCommand.web`'s
  current `('YouTube', 'youtube')` mapping (Verified fact 4) is intentional or a pre-existing
  bug to fix while touching this code — carried over unchanged from the original draft, still
  unresolved.

**Phase 5 — `supportedCommands` derivation (follow-on, separate from the migration).**
**Status:** proposed, optional cleanup. **Risk:** LOW. **Deps:** Phases 0-4 complete (every
command's payload must live in the keymap for this to be safe universally, with no
adapter-level OR-workarounds left).
- Once every adapter's keymap accurately encodes support via `payloadFor`'s `null`/non-`null`,
  `supportedCommands` becomes the same one-liner on every adapter, with no per-adapter
  special-casing:
  ```dart
  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands
      .where((command) => _keyMap.payloadFor(command) != null)
      .toSet();
  ```
- **Interim note (2026-08-21):** ahead of this phase, `supportedCommands` on `SamsungAdapter`
  and `LgAdapter` was already changed to the equivalent `keyCodesFor(...).isNotEmpty` form,
  since those two brands are already fully keymap-driven today (Verified fact 1). AndroidTv,
  TclGoogleTv, and Hisense were changed to an OR-workaround
  (`_keyMap.keyCodesFor(c).isNotEmpty || _appLinks.containsKey(c)`) that checks both the
  keymap and each adapter's separate app-link map, since collapsing them onto keymap-only
  would have wrongly dropped their app-launch commands before Phases 1/4 land. That
  OR-workaround is temporary scaffolding this phase removes, not a preview of the final form.
- `TclRokuAdapter` already proves the plain derivation reproduces its current hand-rolled
  `_supportedCommands` set exactly (its keymapper already returns `[]` for `.web` and nothing
  else is excluded) — cited as validation evidence, not as a reason to migrate Roku first.

## Open questions

1. **Resolved by the 2026-08-21 revision.** ~~Hisense's tuple-payload representation is
   unresolved.~~ `VidaaLaunch(displayName, url)` gives the two pieces of data named fields on
   their own `CommandPayload` subclass instead of forcing them into `List<String>`'s
   "ordered fallback aliases" meaning. Phase 4 is unblocked; see Phased plan.
2. **Resolved by the 2026-08-21 revision.** ~~Should `CommandKeyMap`/`keyCodesFor` be
   renamed?~~ Yes — `keyCodesFor` becomes `payloadFor`, returning `CommandPayload?`. Decided as
   part of the type change itself (see Tradeoffs), not as a separate follow-up.
3. **Obsolete.** The original open question ("exact naming for the adapter-level marker,"
   sketched as `appLinkCommands`) no longer applies — there is no adapter-level marker in the
   revised design; the dispatch decision comes from the `CommandPayload` type returned by
   `payloadFor`, not a separately-named field.
4. **New, raised by this revision:** Phase 0's migration-ordering detail — whether to cut over
   every `keyCodesFor` call site to `payloadFor` atomically, or keep a temporary
   `keyCodesFor`-derived-from-`payloadFor` compatibility shim on `CommandKeyMap` during the
   transition — is left as an implementation-time decision (see Phase 0), not resolved here.

---
