# TEMPORARY: Sony BRAVIA Implementation Notes

**Purpose:** This is a scratch working doc, not a permanent guide. Its only job is to let
you (human or Claude) pick this work back up after a long gap and reconstruct *why* things
are built the way they are, without re-reading the entire goal doc's Decisions log or
re-deriving the reasoning from scratch. **Delete this file once Sub-goal C has been
validated against a real Sony BRAVIA TV** (`A6`/the validation matrix below) — at that
point its content either graduates into `guide-tv-remote-protocols.md` (confirmed facts)
or becomes moot (wrong guesses, corrected).

**Why this doc exists at all:** none of this has been tested on real hardware. The person
building it (Claude) and the person directing it (you) do not own a Sony BRAVIA TV. Every
protocol detail comes from third-party research (`pybravia`, Home Assistant, community
gists), not Sony's own docs (`pro-bravia.sony.net` blocked every fetch attempt with
403/429). That means when this eventually breaks or needs fixing, the fix will likely
require re-deriving intent from written reasoning, not from a memory of "how it works" —
hence this doc.

**Full source of truth**, in order of authority:
1. `references/goals/goal-sony-adapter.md` — the complete decision log, exact citations,
   confidence levels for every research claim.
2. `references/guide-tv-remote-protocols.md` — the "Sony BRAVIA IP Control" section
   (permanent reference, protocol-level facts).
3. `references/sony_bravia_validation_matrix.md` — the on-device checklist for whoever
   gets hardware access.
4. This doc — a faster-to-read synthesis of the above three, plus the *implementation*
   reasoning (why the code is shaped the way it is) that doesn't live in any of them.

---

## Contents

- [Status in one paragraph](#status-in-one-paragraph)
- [File map](#file-map)
- [How a command actually gets from tap to TV](#how-a-command-actually-gets-from-tap-to-tv)
- [Key design decisions and why](#key-design-decisions-and-why)
- [Everything unconfirmed — read this before touching anything](#everything-unconfirmed--read-this-before-touching-anything)
- [Bugs already found and fixed (don't re-discover these)](#bugs-already-found-and-fixed-dont-re-discover-these)
- [What was deliberately not built](#what-was-deliberately-not-built)
- [How to actually fix/validate this once you have a real TV](#how-to-actually-fixvalidate-this-once-you-have-a-real-tv)

---

## Status in one paragraph

`SonyBraviaAdapter` is a second, independent adapter for `TvBrand.sony` (alongside the
already-working `SonyAdapter`, which speaks the unrelated Android TV Remote Protocol v2).
It speaks Sony's own BRAVIA IP Control REST/JSON-RPC API, PIN-mode auth only (no PSK
support). It is fully wired into DI, fully unit-tested (`sony_bravia_test_lane_test.dart`,
`manual_add_variant_probe_test.dart`, plus DI smoke tests), `flutter analyze`/`flutter
test` clean — but **zero lines of this have executed against a real device**. Every IRCC
key name, every app title, the exact pairing handshake shape — all of it is "should be
right based on research," not "confirmed right." Treat it as a well-reasoned draft, not a
finished feature.

---

## File map

```
lib/remote_control/data/adapters/
  sony_adapter.dart                          ← the OTHER Sony protocol (Android TV Remote v2)
                                                — already working, not discussed further here
  sony_bravia_adapter.dart                   ← TvBrandAdapter implementation for THIS protocol
  sony/
    sony_protocol_variants.dart              ← 'sony_bravia_ip_control' variant constant
    sony_bravia_transport_client.dart        ← abstract transport interface
    sony_bravia_http_transport_client.dart   ← real implementation (HTTP, JSON-RPC, IRCC-SOAP)
    sony_bravia_pairing_session_store.dart   ← persists {authHeader, cookie} per host
    sony_bravia_key_mapper.dart              ← RemoteCommand -> IRCC command name
lib/remote_control/debug/
  fake_sony_bravia_transport_client.dart     ← fake for debug builds; fixed PIN '000000'
lib/remote_control/data/
  manual_add_variant_probe.dart              ← picks Sony's variant when manually adding by IP
lib/remote_control/domain/models/
  pin_format.dart                            ← added PinFormat.freeform for Bravia's PIN
lib/remote_control/domain/models/
  tv_capabilities.dart                       ← capability set + pinFormatFor entry for Bravia
lib/remote_control/data/
  ssdp_brand_inference.dart                  ← SSDP fingerprint ('scalarwebapi' substring)
  discovery_variant_resolution_registry.dart ← (Sony, ssdp) -> braviaIpControl entry
  brand_routed_remote_command_service.dart   ← one-line fix so pinFormatFor sees the variant
lib/remote_control/presentation/pages/
  pairing_page.dart                          ← manualAddVariantProbe wiring, TCL fallback
  pairing_page_dialogs.dart                  ← freeform PIN entry (no format validation)
lib/remote_control/configurations/
  remote_control_di_config.dart              ← registers everything above, both configs
```

Tests: `test/lib/remote_control/data/adapters/sony_bravia_test_lane_test.dart`,
`test/lib/remote_control/data/manual_add_variant_probe_test.dart`, two cases added to
`test/lib/remote_control/configurations/remote_control_di_config_test.dart`.

---

## How a command actually gets from tap to TV

**Discovery:** SSDP scanner sees `Sony Corporation` / `ScalarWebAPI` in the response →
`inferSsdpTvBrand` returns `TvBrand.sony` → `DiscoveryVariantResolutionRegistry` stamps
`protocolVariant = 'sony_bravia_ip_control'` on the `TvDevice` right there, before any
adapter has run.

**Manual add by IP:** no discovery signal exists, so `ManualAddVariantProbe` TCP-probes
each of Sony's two adapters' hosts and takes whichever one answers first, in order
`[defaultVariant (Google TV path), braviaIpControl]` — i.e. it prefers the *other*,
already-working Sony protocol if both happen to answer.

**Pairing:** `preparePairing` calls `registerPin(pin: null)` — this call is *expected* to
fail (HTTP 401), and that failure is literally what makes the TV display an on-screen PIN.
The failure surfaces as `PinRequiredException`, which the app's generic pairing-dialog
flow already knows how to handle (same mechanism Hisense uses). User types the PIN →
`submitPairingCode` → `registerPin(pin: enteredPin)` → this time (if correct) the TV
returns a session cookie, which gets saved alongside the *original* Basic-Auth header
(`Basic base64(":"+pin)`) — **both** must be replayed on every future request, not just
the cookie. This two-piece requirement is easy to get wrong; see the "cookie bug" below.

**Sending a command:** `SonyBraviaAdapter.sendCommand` first checks if it's an app-launch
command (Netflix/YouTube/Prime/Disney+); if not, it looks up an IRCC command *name*
(`'Up'`, `'VolumeUp'`, `'Power'`, ...) from `sony_bravia_key_mapper.dart` and asks the
transport to send it. The transport has never hardcoded an actual IRCC *code* — on first
use per device it calls `getRemoteControllerInfo` once, caches the TV's own
name→base64-code table, and looks up the requested name in that live table. If the name
isn't in that table, it throws — it does not guess.

**App launch:** same idea, one level up — `getApplicationList` is fetched once per device
and cached as a title→uri map; `resolveAppUri` matches the wanted title (exact match
first, substring fallback) and `launchApp` calls `setActiveApp` with the resolved uri.

---

## Key design decisions and why

- **`SonyBraviaAdapter` is a sibling of `SonyAdapter`, not a subclass.** They share only
  `TvBrand.sony`. Different transport, different key mapper, different pairing flow,
  different capabilities. Don't try to unify them — they're genuinely unrelated protocols
  that happen to hit the same brand enum value.

- **Command dispatch is IRCC-by-name for almost everything, not the separate REST verbs**
  (`setPowerStatus`, `setAudioVolume`, etc.) the research initially catalogued. Decided
  during implementation: IRCC already covers every physical remote button, so building a
  second dispatch mechanism for a handful of commands wasn't worth it. If a future need
  arises for REST-verb-specific behavior (e.g., setting an exact volume percentage instead
  of a relative up/down), that's a deliberate scope expansion, not a bug to "fix back."

- **IRCC codes and app URIs are never hardcoded — always resolved live, per device.**
  Sony assigns these per model/firmware; a table baked into the app would silently be
  wrong for some devices. If you're tempted to add a static code table "to make this
  faster," don't — that reintroduces exactly the risk this design avoids.

- **App-launch title matching is cached inside the *transport*, keyed by host — not
  passed through the `CommandKeyMap`/`VariantKeyMap` mechanism every other brand uses.**
  This was a real, deliberate correction mid-session: `SonyBraviaAdapter` is one shared
  instance across every paired Bravia TV (confirmed via
  `brand_routed_remote_command_service.dart`'s `(brand, variant) -> adapter` map — there
  is no per-device adapter instance anywhere in this codebase). A shared mutable
  `CommandPayload` override map would have leaked one TV's app URIs onto a second TV's
  commands. Keeping the cache in the transport, keyed by host, is what makes multi-device
  correctness actually hold.

- **`supportedCommands` reports the four app-launch commands unconditionally** (optimistic
  — it can't know per-device availability, since the interface has no `device` parameter
  and this app has no precedent for making it one). A device missing an app just fails
  cleanly at tap time (`UnsupportedError`) rather than silently mis-dispatching. This is a
  known, accepted UX rough edge, not an oversight.

- **`_sendFirstWorkingKey` tries key-name aliases in order** (e.g. `'Power'` then
  `'TvPower'`) because two independent community device dumps disagreed on the name for
  the identical code — this is real cross-firmware naming drift, not redundancy.

- **`ManualAddVariantProbe`'s TCL fallback logic looks oddly specific — it's load-bearing,
  not decorative.** `TvDevice`'s constructor defaults `protocolVariant` to `'default'`,
  but `TclLegacyWifiAdapter.protocolVariant` is `'tcl_legacy_wifi'`. Without special-casing
  this, a manually-added TCL device with no probe wired would resolve to a `(brand,
  variant)` pair with no adapter behind it at all — pairing would fail outright, not
  degrade gracefully. Traced via `git log -S` to the original ternary this replaced
  (`a9f75dda`) to confirm this wasn't invented paranoia.

---

## Everything unconfirmed — read this before touching anything

Ranked roughly by how likely each is to be wrong:

1. **`menu` → IRCC name `'Options'`.** Two source dumps agreed on this name, but
   `'TopMenu'` and `'AndroidMenu'` are real alternative candidates seen in the same
   research. If menu does the wrong thing (or nothing) on a real TV, this is the first
   place to look — check the TV's own `getRemoteControllerInfo` response for the actual
   available name.
2. **Prime Video (`'prime video'`) and Disney+ (`'disney+'`) app titles are best-guess
   substrings**, not confirmed against any real device dump (unlike Netflix/YouTube,
   which are confirmed). If launch fails for these specifically, log the real
   `getApplicationList` response and fix the string in
   `SonyBraviaAdapter._appLaunchTitles`.
3. **The PIN-mode `actRegister` flow's exact two-call shape** (no-PIN call triggers
   on-screen display, second call with PIN completes) is inferred from `pybravia`'s
   source and general JSON-RPC-with-challenge convention — never observed directly
   against a Sony endpoint.
4. **Whether the TV's SSDP responder is active before "IP Control" is manually enabled in
   TV settings** — completely unresolved either way. If discovery doesn't find a Bravia TV
   at all, check this first before assuming the SSDP fingerprint itself is wrong.
5. **The `scalarwebapi` SSDP fingerprint's specificity** — confirmed it's Sony-exclusive
   (vendor-namespaced URN), but also confirmed it's shared with Sony's non-TV "Songpal"
   audio gear. If a Sony soundbar on the same network ever gets misidentified as a TV,
   this is why.
6. **`getSystemInformation`'s response shape** (used for `queryDeviceInfo`) — the
   `model`/`generation` field names are a guess; this is wrapped in a try/catch that
   degrades to a generic placeholder on any failure, so it fails safe, but the model
   name shown to the user may just be wrong/generic on a real TV.

---

## Bugs already found and fixed (don't re-discover these)

Found on a deliberate, careful re-read after the user pointed out that "regression
testing" had only meant re-running `flutter analyze`/`flutter test`, not actually hunting
for logic bugs in new code:

1. **Cookie header corruption.** `Set-Cookie` response values carry attributes (`Path`,
   `HttpOnly`, ...) after the first `;` that must never be echoed back in a `Cookie:`
   request header. Original code joined the raw values directly — fixed with
   `Cookie.fromSetCookieValue` to extract just `name=value`. If this regresses, every
   request after the first successful pairing would fail.
2. **Silent JSON-RPC error swallowing.** Sony's REST API reports semantic failures as
   `{"error": [...]}` on an HTTP 200 — the code only checked HTTP status. Worst case was
   `launchApp` reporting success even when the TV rejected the launch. Fixed by checking
   for the `error` key explicitly.
3. **`ManualAddVariantProbe` silently dropping unlisted candidates** instead of
   deprioritizing them — see the design-decisions section above.

---

## What was deliberately not built

- **PSK static-key auth.** Needs a brand-new "type in a permanent key" UI screen with no
  precedent anywhere in this app (the existing PIN dialog assumes a live, TV-displayed
  code, not a pre-configured static one). If someone eventually builds this, it's a new
  manual-entry field, not a re-use of `PairingPageDialogs.promptPairingPin`.
- **Simple IP Control (legacy TCP/20060).** The FOSS ecosystem has moved past it; no
  concrete need identified for pre-2013 Sony sets.
- **Text input (`sendText`).** No BRAVIA REST endpoint for it was found during research.
- **`web`/browser and `playPause` commands.** No generic browser app found; no single
  toggle code exists for play/pause (only separate `Play`/`Pause`, which are genuinely
  different actions — aliasing them would send the wrong one half the time).

---

## How to actually fix/validate this once you have a real TV

1. Read `references/sony_bravia_validation_matrix.md` and work through it top to bottom.
2. For anything in the "unconfirmed" list above that turns out wrong, the fix is almost
   always a one- or two-line change in `sony_bravia_key_mapper.dart` (IRCC names) or
   `SonyBraviaAdapter._appLaunchTitles` (app titles) — not a structural change.
3. Turn on verbose logging by watching `SonyBraviaHttpTransportClient`'s emitted
   `TransportEvent`s (transport `'sony_bravia'`) — every key send and app launch emits
   one; this is the fastest way to see exactly what code/uri was actually sent.
4. Once confirmed correct, update `guide-tv-remote-protocols.md`'s Bravia section's
   confidence levels (many are currently "medium" or "best-guess" pending exactly this),
   and check off the corresponding rows in `sony_bravia_validation_matrix.md`.
5. Once every row in the validation matrix is checked, this file (the one you're reading)
   should be deleted — its job is done, everything durable belongs in the guide by then.
