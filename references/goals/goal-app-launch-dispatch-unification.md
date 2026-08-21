# Goal: App-Launch Dispatch Unification

**Branch:** `feature/command-drawer` (current)
**Status:** proposed — planning only, not yet approved for implementation
**Related:** none of the other `references/goals/` docs touch this surface directly; this is
an independent adapter/keymapper-layer cleanup, not coupled to the layout/drawer work.
**Origin:** surfaced during a design review of how `RemoteCommand.netflix` / `.primeVideo` /
`.disneyPlus` / `.youtube` / `.web` ("app-launch commands") are dispatched across the seven
`TvBrandAdapter` implementations.

> ⚠️ **This document has not been verified or approved by the user beyond an initial lean
> toward the direction below.** Every claim under "Verified facts" was confirmed by direct
> source reads (file:line cited) as of 2026-08-21. "Proposed target design" and the phased
> plan are unevaluated proposals, not decisions. Nothing in `lib/` has been touched to
> produce this document.

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
   21-value `RemoteCommand` enum and includes all five app-launch commands; Samsung, LG,
   AndroidTv, TclGoogleTv, and Hisense all currently return this constant unchanged from
   `supportedCommands` (confirmed at each adapter's `supportedCommands` getter).

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

For every brand, app-launch payloads move **into that brand's `CommandKeyMap`**, delivered
through `keyCodesFor` exactly like any other command's payload. Each adapter gains an explicit
marker — sketched here as `Set<RemoteCommand> appLinkCommands` (naming not finalized) — so
`sendCommand` becomes a two-branch shape instead of a mechanism-specific one:

```dart
Future<void> sendCommand({required TvDevice device, required RemoteCommand command}) async {
  await _transportClient.connect(deviceId: device.id);
  if (appLinkCommands.contains(command)) {
    final payload = _keyMap.keyCodesFor(command);
    await _transportClient.sendAppLink(deviceId: device.id, appLink: payload.single); // brand-specific call
    return;
  }
  final keyCodes = _keyMap.keyCodesFor(command);
  if (keyCodes.isEmpty) throw UnsupportedError('No mapping for command: $command');
  for (final keyCode in keyCodes) {
    await _transportClient.sendKey(deviceId: device.id, keyCode: keyCode);
  }
}
```

Concretely, per brand:
- **AndroidTv/TclGoogleTv:** `AndroidTvKeyMapper` gains the four `market://launch?id=...`
  entries; both adapters' duplicate `_appLinks` maps are deleted; `sendAppLink` stays exactly
  as it is today (no transport change needed).
- **Samsung/LG:** the keymap keeps returning the app id / launch id as its single list
  element (dropping the `LAUNCH:` prefix, since the adapter now knows structurally which
  commands are launches instead of needing to sniff a string), and the transport clients gain
  a real `sendAppLink`-equivalent method to replace the removed `startsWith` branch —
  `SamsungWebSocketTransportClient` already has `launchApp(deviceId:, appId:)` privately
  (`samsung_websocket_transport_client.dart:295`); it would become a proper public method
  called directly by the adapter instead of being reached via string-sniffing inside
  `sendKey`. LG's `_sendSsap(uri: 'ssap://system.launcher/launch', payload: {'id': appId})`
  call (`lg_websocket_transport_client.dart:719-723`) would similarly need a named,
  adapter-callable entry point.
- **TclRoku:** `TclRokuKeyMapper` gains the four Roku-channel-id entries; `_appIds` is deleted;
  `launchApp` stays as-is.
- **Hisense:** blocked on the open question below — needs either a documented two-slot
  convention (`[displayName, url]`) or a different payload representation, since `keyCodesFor`
  today means "ordered fallback aliases," not "positional fields of one payload." Sequenced
  last for this reason.

## Tradeoffs (honest accounting, not oversold)

- **Not a clean OCP win.** Today, adding a new app-link command to AndroidTv/TclRoku means
  touching one map (`_appLinks`/`_appIds`). Under this proposal it means touching two
  collections: the keymap entry *and* `appLinkCommands` set membership. Roughly a wash on
  this specific axis — the payoff is consistency and the Samsung/LG SRP fix, not fewer edit
  points for this particular case.
- **Real migration surface, not a small patch.** Touches 5 adapters, 4 distinct keymapper
  classes (`SamsungKeyMapper`, `LgKeyMapper`, `AndroidTvKeyMapper` — shared by AndroidTv and
  TclGoogleTv, `TclRokuKeyMapper`), the Samsung/LG transport clients (each needs a genuine
  `sendAppLink`-equivalent method to replace the removed `startsWith` branch), and every
  existing test asserting on `_appLinks`/`_appIds`/`_vidaaLaunchSpec`/"keymap returns `[]` for
  these five commands" behavior. This should be phased per-brand (see below), not landed as
  one large change.
- **Naming stretch, arguably project-wide, left unresolved here.** `CommandKeyMap`/
  `keyCodesFor` reads as "key codes," but once app ids/URIs/(eventually) tuples live there too,
  the name undersells what it holds — LG already stretches this today with `POINTER:`/
  `TOGGLE:` sentinels (Verified fact 1), so the stretch predates this refactor; this refactor
  just makes it universal instead of fixing it. See Open questions — not decided here, and
  nothing gets renamed as part of this plan without a separate decision.

## Phased plan

Ordered by confidence/risk, per the background discussion: the AndroidTv/TclGoogleTv
duplicate-map collapse is the highest-confidence, lowest-risk move (no transport-layer
changes, deletes a proven duplication bug); Samsung/LG is the real SRP fix but requires new
transport-client methods; Hisense is last because its tuple-payload representation is an open
design question, not a solved detail. The `supportedCommands` derivation is a distinct,
later-sequenced follow-on, not entangled with the migration itself.

**Phase 1 — AndroidTv + TclGoogleTv.**
**Status:** proposed. **Risk:** LOW. **Deps:** none.
- Add the four `market://launch?id=...` entries to `AndroidTvKeyMapper` (already shared by
  both adapters).
- Add `appLinkCommands` (or equivalent) to `AndroidTvAdapter` and `TclGoogleTvAdapter`.
- Delete both adapters' `_appLinks` maps.
- No transport-client change — `sendAppLink` is untouched.
- Update/extend any test that constructs or asserts against `_appLinks` directly.

**Phase 2 — TclRoku.**
**Status:** proposed. **Risk:** LOW. **Deps:** none (independent of Phase 1).
- Add the four Roku-channel-id entries to `TclRokuKeyMapper`; delete `_appIds`.
- Add `appLinkCommands` to `TclRokuAdapter`.
- No transport-client change — `launchApp` is untouched.
- Confirm `TclRokuAdapter.supportedCommands`'s existing hand-rolled set is unaffected (it stays
  hand-rolled until Phase 4).

**Phase 3 — Samsung + LG.**
**Status:** proposed. **Risk:** MEDIUM. **Deps:** none (independent of Phases 1-2), but should
land after them so the pattern is proven on lower-risk brands first.
- Keymap entries drop the `LAUNCH:` prefix, becoming a plain app id/launch id string.
- Add `appLinkCommands` to `SamsungAdapter`/`LgAdapter`.
- Give each transport client a real, adapter-callable app-launch method
  (`SamsungWebSocketTransportClient.launchApp` promoted from private; LG needs an equivalent
  named entry point wrapping its existing `ssap://system.launcher/launch` call) and remove the
  `startsWith(samsungLaunchPrefix)` / `startsWith(lgLaunchPrefix)` branches from `sendKey`.
- LG's `POINTER:`/`TOGGLE:` sentinels are explicitly **not** touched by this phase — only the
  `LAUNCH:` convention is being removed; the other two sentinel conventions are a separate,
  unscoped concern.
- Update every test asserting on the `LAUNCH:` prefix or the transport clients'
  `startsWith` branches.

**Phase 4 — Hisense.**
**Status:** proposed, blocked on the open question below. **Risk:** MEDIUM-HIGH (payload-shape
design question unresolved). **Deps:** a decision on how to represent the `(displayName, url)`
tuple in/alongside `keyCodesFor`.
- Requires deciding one of: (a) a documented `[displayName, url]` two-slot convention on
  `keyCodesFor`'s `List<String>` return (collides with the "ordered fallback list" meaning used
  by every other command), or (b) a different payload shape/type carried alongside or instead
  of `List<String>` for this one brand.
- Separately, decide (not as part of the mechanical migration) whether `RemoteCommand.web`'s
  current `('YouTube', 'youtube')` mapping (Verified fact 4) is intentional or a pre-existing
  bug to fix while touching this code.
- Add `appLinkCommands` to `HisenseAdapter`; `HisenseKeyMapper`'s five empty-list entries
  become real payloads once (a)/(b) above is decided.

**Phase 5 — `supportedCommands` derivation (follow-on, separate from the migration).**
**Status:** proposed, optional cleanup. **Risk:** LOW. **Deps:** Phases 1-4 complete (every
command's payload must live in the keymap, empty list = "not supported," for this to be safe
universally).
- Once every adapter's keymap accurately encodes support via non-empty/empty lists,
  `supportedCommands` can be derived instead of hand-maintained:
  ```dart
  @override
  Set<RemoteCommand> get supportedCommands => kCommonSupportedRemoteCommands
      .where((command) => _keyMap.keyCodesFor(command).isNotEmpty)
      .toSet();
  ```
- `TclRokuAdapter` already proves this derivation reproduces its current hand-rolled
  `_supportedCommands` set exactly (its keymapper already returns `[]` for `.web` and nothing
  else is excluded) — cited as validation evidence for the approach, not as a reason to
  migrate Roku first; Roku's current code already works and migrating it to the derived form
  is optional cleanup, not required.
- This was previously unsafe for AndroidTv/Hisense/TclRoku specifically because those
  adapters' keymaps deliberately left app-link commands empty for *other* reasons (the
  separate-map/tuple mechanisms above) — once Phases 1-4 remove those reasons, the derivation
  becomes safe everywhere.

## Open questions

1. **Hisense's tuple-payload representation is unresolved.** `launchVidaaApp` needs two
   pieces of data (`displayName` and `url`); `CommandKeyMap.keyCodesFor` returns a flat
   `List<String>` whose established meaning elsewhere is "ordered fallback key-code aliases to
   try" (e.g. Samsung's `back` trying `KEY_RETURN` then `KEY_BACK`) — a different semantic from
   "two positional fields of one payload." Migrating Hisense into the unified scheme needs
   either a documented convention (`[displayName, url]` as fixed positional slots, which
   collides with the fallback-list meaning used everywhere else) or a different payload
   shape/type just for this case. Not solved by this document — Phase 4 is blocked on it.
2. **Should `CommandKeyMap`/`keyCodesFor` be renamed** (e.g. to something like
   `CommandMap`/`payloadFor`) now that app ids/URIs/(potentially) tuples live there, not just
   key codes? LG already stretches the current name today via its `POINTER:`/`TOGGLE:`
   sentinels (Verified fact 1) — this refactor makes the stretch universal rather than
   introducing it, but doesn't fix it either. This is a naming decision to make, not decided by
   this document, and nothing should be silently renamed as a side effect of the phases above.
3. (Minor, not blocking) **Exact naming for the adapter-level marker** — sketched here as
   `appLinkCommands`, but not finalized; a final name should be chosen when Phase 1 actually
   starts, consistently across all five adapters.

---
