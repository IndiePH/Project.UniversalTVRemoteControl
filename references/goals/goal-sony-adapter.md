# Goal: Sony TV Adapter

**Branch:** `feature/sony-adapter` (current)
**Status:** planning — no implementation started
**Related:** `references/guide-protocol-variants.md` (variant mechanism this goal partly relies on, partly may not fit — see Open questions), `references/guide-android-tv-remote-protocol.md` (the shared protocol Sub-goal A reuses)

> ⚠️ **This document has not been verified or approved by the user beyond the initial
> breakdown.** Sub-goal A's design is grounded in a direct source read of
> `tcl_google_tv_adapter.dart` (high confidence). Sub-goal B/C's protocol details come from
> external web research this session (see citations) — several points are explicitly
> medium-confidence or unverified because Sony's own developer docs
> (pro-bravia.sony.net) returned 403/429 to every fetch attempt this session. Treat anything
> not marked "high confidence" as needing a follow-up check, not a settled fact.

---

## Problem statement

Sony is not currently a selectable device brand anywhere in the app. `TvBrand`
(`lib/remote_control/domain/models/tv_brand.dart:1`) is `{samsung, lg, hisense, androidTv,
roku, tcl}` — no `sony`. The goal is to make Sony a first-class brand, similar to how
`androidTv`, `lg`, `samsung`, and `tcl` already work.

Sony TVs can be reached via two genuinely different protocols, confirmed independent of
each other (see Sub-goal B research):

1. **Google's Android TV Remote protocol** — the same protobuf-based protocol
   `TvBrand.androidTv` and `TvBrand.tcl` (`TclGoogleTvAdapter`) already use.
2. **Sony's own BRAVIA IP Control** (REST/IRCC-IP over HTTP, or legacy Simple IP Control
   over TCP) — Sony-proprietary, not shared with any other brand in this codebase.

This is being split into three sub-goals so the well-understood, low-risk path (A) can ship
independently of the higher-uncertainty research-and-build path (B → C).

---

## Verified facts

### Codebase (direct source reads, high confidence)

1. `TclGoogleTvAdapter` (`lib/remote_control/data/adapters/tcl_google_tv_adapter.dart:28-140`)
   is a thin wrapper: it composes an injected `AndroidTvTransportClient` +
   `AndroidTvKeyMapper` (via `VariantKeyMap`), declares `brand => TvBrand.tcl` and
   `protocolVariant => TclProtocolVariants.googleTv`, and otherwise delegates every method
   straight to the shared transport client. It has **zero TCL-specific protocol logic** —
   the only TCL-specific thing is a hardcoded app-link override map for 4 commands
   (Netflix/Prime/Disney+/YouTube) because TCL's Google TV builds weren't verified against
   the default `https://` App Link URIs (lines 13-26). This is the template for Sub-goal A.
2. `TvBrand` enum + `TvBrandDisplay` extension live together in one 12-line file
   (`tv_brand.dart`) — adding `sony` is a two-line change (enum value + switch arm).
3. Adapters are registered via a plain list literal in
   `lib/remote_control/configurations/remote_control_di_config.dart` at **two** locations
   (lines ~154-161 and ~234-239, per prior Explore pass) — both need the new adapter added,
   not just one.
4. Protocol-variant resolution (`variant_resolution_registry.dart`) is driven by a predicate
   over `TvDeviceInfo` (`modelIdentifier`/`firmwareVersion`) evaluated once at pairing time
   and stamped onto `TvDevice.protocolVariant` — see Open questions for why this may not
   cleanly fit Sony's two-protocol situation.

### Sony Android/Google TV protocol (external research, this session)

5. **High confidence:** Sony's entire 2021+ lineup runs Google TV, continuing through 2024-2025
   models (Bravia 9/8/7/3, Bravia 8 II) — confirmed across Tom's Guide, FlatpanelsHD,
   Notebookcheck. No documented 2021+ Sony model ships without Google TV.
6. **Medium-high confidence:** Sony was an early Android TV adopter (2015-2016,
   X850C/X930D-era) on an **older "Android TV Remote protocol V1"**, distinct from the
   current protobuf V2 protocol that `AndroidTvAdapter`/`TclGoogleTvAdapter` speak. A Home
   Assistant community thread
   (https://community.home-assistant.io/t/android-tv-remote-v1/785231) documents a Sony unit
   stuck on V1 until a firmware/app update pushed V2. **Implication: 2021+ compatibility is
   the safe claim; pre-2021 "Android TV" (not "Google TV") Sony sets are not guaranteed to
   work with the generic adapter** — depends on whether that unit's system app was updated.
7. **Low-medium confidence, mixed evidence:** No documented Sony-specific deviations in key
   codes or app-link URI schemes. But real connectivity bugs are reported disproportionately
   against Sony specifically: pairing failure on a Sony KD-49XD7005
   (home-assistant/core#97461, since fixed) and devices going "unavailable" ~2 min after
   connecting (home-assistant/core#165399). Read as reliability edge cases, not a protocol
   incompatibility — but worth being aware of during testing.
8. **High confidence:** Sony's own BRAVIA IP Control and the Android TV Remote Service are
   independent systems that can be active simultaneously on the same TV — confirmed via
   home-assistant/core#84557 (IP Control failures isolated to the separate `braviatv`
   integration, don't affect Android TV Remote connectivity on the same unit).

### Sony BRAVIA IP Control (external research, this session)

9. **High confidence:** at least two protocol generations exist under the "IP Control"
   umbrella:
   - **Simple IP Control (SSIP)** — legacy plaintext binary TCP, fixed port **20060**, fixed
     24-byte packets. Sony's own pages (pro-bravia.sony.net/remote-display-control/simple-ip-control,
     .../develop/integrate/ssip/overview) could not be fetched directly this session
     (403/429) — corroborated instead via RTI/Crestron third-party integrator docs.
   - **BRAVIA REST API / IRCC-IP** — JSON-RPC over **HTTP, port 80**, endpoints under
     `/sony/<service>` (system, avContent, appControl, audio, ...), plus a SOAP/base64
     sub-path (`/sony/IRCC`) for raw key-press emulation. Confirmed via a working example in
     https://gist.github.com/kalleth/e10e8f3b8b7cb1bac21463b0073a65fb and
     https://helpguide.sony.net/tv/gusltnr1/v1/en-us/07-02_17.html (both fetched
     successfully).
10. **Auth (high confidence for PSK, medium for PIN flow):**
    - PSK mode: enabled in TV settings, then every HTTP request carries header
      `X-Auth-PSK: <key>`. Verified working example:
      ```
      curl -H "X-Auth-PSK: your_key" -X POST \
        -d '{"id":20,"method":"PowerOff","version":"1.0","params":[]}' \
        http://192.168.0.98/sony/system
      ```
    - PIN/challenge mode — **resolved 2026-08-24, see Decisions log**: `POST
      /sony/accessControl`, JSON-RPC method `actRegister` v1.0. Pairing-initiation and
      PIN-confirmation are the *same* call shape; the PIN itself travels as HTTP Basic Auth
      (`Authorization: Basic base64(":"+pin)`), not in the JSON body. On success the TV
      returns a `Set-Cookie` header, but the client must keep **both** the cookie *and* the
      original Basic-Auth header attached to every subsequent request for the life of the
      session — cookie-only was a wrong assumption, corrected via direct source read of
      `pybravia` (high confidence).
11. **High confidence command catalog:** power (`getPowerStatus`/`setPowerStatus`),
    volume/mute, input switching (`setPlayContent` + HDMI URI), app list/launch
    (`getApplicationList`/`setActiveApp`), remote-key emulation via IRCC base64 codes,
    system/network/reboot endpoints.
12. **Medium confidence, key open point:** REST/IRCC-IP is documented as available
    "2013 and newer" (pybravia, HA docs) — i.e. it covers a *broader* device range than the
    Android TV Remote protocol does, not a narrower "legacy fallback" range. This inverts the
    original "new TVs use Google protocol, old TVs use Bravia as fallback" framing — Bravia
    is closer to the universal option, Google protocol is the newer/narrower one.
13. Known open-source implementations: `pybravia` (async, HA's backend, PSK + PIN, 2013+),
    `braviaproapi`, `irccip-go`. **None of these auto-detect protocol generation** — they let
    the caller pick PSK vs. PIN, and none reference falling back to Simple IP Control. The
    FOSS ecosystem has standardized on REST/IRCC-IP; Simple IP Control appears mostly in
    commercial AV control systems (Crestron/RTI).

### Discovery & brand classification mechanics (direct source reads, high confidence, 2026-08-24)

14. `DeviceDiscoveryService` (`application/device_discovery_service.dart:3-5`) is run as a
    `CompositeDeviceDiscoveryService` (`data/composite_device_discovery_service.dart:12-53`)
    that fans out to three independent scanners in parallel and merges results — not one
    scan classified centrally, and not one-scanner-per-brand-adapter:
    - `SsdpDeviceDiscoveryService` — one generic SSDP M-SEARCH broadcast, brand assigned
      afterward by `inferSsdpTvBrand` (`data/ssdp_brand_inference.dart:30-49`) via substring
      match on SSDP headers. **Today this only matches `samsung`/`tizen`, `lg`/`webos`,
      `hisense`/`vidaa`/`hiview`, `roku`, and `androidtvremote` strings — no `sony`, `bravia`,
      or `tcl` fingerprint exists.** Non-matches return `null`.
    - `MdnsDeviceDiscoveryService` — dedicated mDNS browse for `_androidtvremote2._tcp`
      (the Android TV Remote protocol's own advertisement). **`_resolveToDevice`
      (`data/mdns_device_discovery_service.dart:94-100`) hardcodes `brand:
      TvBrand.androidTv` for every device it resolves — there is no manufacturer detection
      here at all**, for any brand. Every device speaking this protocol (Sony, TCL,
      Chromecast, generic Google TV) is returned as `androidTv`.
    - `RokuSsdpDiscoveryService` — separate Roku-specific client.
15. `DiscoveryResultMerger.mergeByHost` (`data/discovery_result_merger.dart:8-25`) dedupes
    by IP (`device.resolvedHost`); on a collision it keeps whichever candidate has the
    **lower** `DiscoveredDeviceSupport.brandIdentificationPriority` number
    (`application/discovered_device_support.dart:30-37`):
    `samsung=0, lg=1, hisense=2, roku=3, androidTv=4, tcl=5` — i.e. `androidTv` already
    outranks (wins over) `tcl` today whenever both are found at the same IP. The doc comment
    on this method calls it "relative confidence when multiple discovery paths report the
    same IP" — a generic protocol-level detection (mDNS) is trusted over a brand-string
    guess (SSDP) for TCL's case.
16. **Net effect for Sony, confirmed:** under Sub-goal A's plan (Sony via the shared Android
    TV Remote protocol, no dedicated SSDP fingerprint added), a Sony TV found via mDNS will
    surface in the discovery list labeled **"Android TV," not "Sony"** — identical to how
    TCL's mDNS-found devices behave today. This is existing, general behavior, not a
    Sony-specific gap.

---

## Open questions (unresolved — do not start Sub-goal C until these are answered)

1. ~~**How does a user actually select/pair a Bravia-path Sony device...**~~ —
   **resolved 2026-08-24 (B2), pending user sign-off**, see Decisions log for the full
   writeup. Summary: Sony BRAVIA IS independently SSDP-discoverable
   (`urn:schemas-sony-com:service:ScalarWebAPI:1`), so this isn't purely a manual-entry
   problem. But `TvDeviceInfo`/the predicate registry is structurally the wrong place to
   pick between the two protocols — `BrandRoutedRemoteCommandService.preparePairing`
   (`brand_routed_remote_command_service.dart:60`) selects the adapter via
   `device.protocolVariant` **before** `queryDeviceInfo()` is ever called, so the variant
   must already be correct at `TvDevice` construction time (i.e. stamped by the discovery
   scanner itself), not resolved afterward. ~~Leaning: closer to TCL's 3
   separately-selectable adapters~~ — **correction:** TCL has no real multi-variant picker;
   `pairing_page.dart:534-536` shows manual-add hardcodes
   `brand == TvBrand.tcl ? legacyWifi : default` — a ternary, not a UI selector. There is
   **no existing precedent** for a user manually choosing between two live variants of one
   brand; Sony's manual-add path needs genuinely new UI.
2. ~~**Exact PIN-pairing endpoint/cookie shape for BRAVIA REST** is unverified~~ —
   **resolved 2026-08-24 (B1)**, see verified fact #10 and Decisions log. Sony's own docs
   (pro-bravia.sony.net) are still blocked (403) as of this pass, including a Wayback Machine
   attempt (tool-blocked, not just unsuccessful) — resolved instead via direct read of
   `pybravia`'s source, cross-checked against Home Assistant's `braviatv` integration.
3. **Should Simple IP Control (legacy TCP/20060) be in scope at all**, given the FOSS
   ecosystem has largely abandoned it in favor of REST/IRCC-IP? Leaning no — recommend
   scoping Sub-goal C to REST/IRCC-IP only unless a concrete need for pre-2013-era Sony sets
   surfaces.

---

## Sub-goal A — Sony Google/Android TV support (default path, ships now)

No dependency on B/C. Low risk — mirrors an existing, working pattern (`TclGoogleTvAdapter`)
exactly.

- [x] **A1. Add `TvBrand.sony` enum value + display name ("Sony")** — done 2026-08-24.
      Detail: two-line change to `tv_brand.dart` per verified fact #2. Deps: none. Risk: LOW.
      Skills: language-specific-implementation.
- [x] **A2. Create `SonyAdapter`** reusing `AndroidTvTransportClient`/`AndroidTvKeyMapper`,
      mirroring `TclGoogleTvAdapter` structure (verified fact #1). Decide whether any
      app-link override map is needed for Sony (TCL needed one for 4 commands; unknown yet
      whether Sony's Google TV builds have the same gap — default to none unless found
      otherwise during A5 manual testing). — **done 2026-08-24: no override map added** (plain
      `AndroidTvKeyMapper`, no `VariantKeyMap`), per this task's own default-to-none guidance;
      revisit during A6 manual testing if Sony's Google TV builds turn out to need one.
      `protocolVariant` implemented as `SonyProtocolVariants.defaultVariant` (new file
      `lib/remote_control/data/adapters/sony/sony_protocol_variants.dart`, mirrors
      `AndroidTvProtocolVariants`/`SamsungProtocolVariants`'s single-variant pattern) —
      this constant's registration in the variant-resolution registry is still A3's job.
      Detail: new file `lib/remote_control/data/adapters/sony_adapter.dart`. Deps: A1. Risk:
      LOW. Skills: language-specific-implementation, framework-mastery,
      design-pattern-selection.
      **Known consequence (confirmed via `dart analyze`, not yet fixed — this is A3/A4's
      job):** adding the `sony` enum value makes 3 existing exhaustive switches over
      `TvBrand` fail to compile until each gets a `sony` case:
      `application/discovered_device_support.dart` (2 switches: `tierFor`,
      `brandIdentificationPriority`), `debug/runtime_flags_template_debug.dart`. This is the
      expected, by-design state after A1+A2 alone (Dart's exhaustiveness check is exactly
      what forces every brand-aware call site to be updated) — A3/A4 close these out.
- [x] **A3. Register default variant-resolution catch-all + `TvCapabilities` entry** for
      `TvBrand.sony` (mirrors every other single-variant brand — see verified fact re:
      `android_tv_protocol_variants.dart`/`samsung_protocol_variants.dart` pattern in the
      protocol-variant guide). — **done 2026-08-24.**
      Detail: edits to `variant_resolution_registry.dart` (catch-all entry, mirrors
      `androidTv`/`samsung`) and `tv_capabilities.dart` (capability set mirrors `androidTv`
      exactly — `keyCommands, powerControl, pinPairing, textInput` — since `SonyAdapter`
      wraps the identical transport/protocol; `pinFormatFor` also mirrors `androidTv`'s
      `PinFormat.sixCharHex`, since `SonyAdapter.submitPairingCode` delegates to the same
      `AndroidTvTransportClient` whose pairing code is documented as 6-char hex). Deps:
      A1, A2. Risk: LOW. Skills: language-specific-implementation.
      **Also closed out (not a new task — these were the 3 compile errors flagged as a known
      consequence under A2):** added the missing `TvBrand.sony` case to the two exhaustive
      switches in `discovered_device_support.dart` (`tierFor` → `DeviceSupportTier
      .experimental`, mirroring `androidTv`/`tcl`; `brandIdentificationPriority` → `6`,
      lowest/last, since no SSDP/mDNS fingerprint tags anything as `sony` yet per verified
      fact #14) and to `runtime_flags_template_debug.dart` (mirrors `androidTv`/`roku`'s
      plain two-flag template — no Sony-specific dart-define flags exist). `dart analyze`
      confirmed 0 issues project-wide after these edits.
- [x] **A4. Wire `SonyAdapter` into DI config (both list locations) + UI brand-selection
      list/icon** — done 2026-08-24.
      Detail: `remote_control_di_config.dart` — added `SonyAdapter(transportClient:
      sl<AndroidTvTransportClient>())` to both adapter-list literals (release
      `RemoteControlDiConfig`, ~line 158, and `DebugRemoteControlDiConfig`, ~line 240) plus
      one import line. Reused the already-registered `AndroidTvTransportClient` singleton in
      both configs (release: the real `AndroidTvTcpTransportClient`; debug:
      `FakeAndroidTvTransportClient`) rather than registering a second transport, per this
      task's own instruction — `SonyAdapter` has no transport of its own (verified fact #1
      pattern). Noted the `TclGoogleTvAdapter`-not-registered discrepancy
      (`tcl_protocol_variants.dart` comment: TCL's Google-TV-variant devices fall back to
      `AndroidTvAdapter`, so `TclGoogleTvAdapter` is dead code, never added to either list)
      but did not treat it as precedent — `TvBrand.sony` is a real, user-selectable brand
      with its own capabilities/variant registration from A1/A3, so `SonyAdapter` genuinely
      needed registering, unlike `TclGoogleTvAdapter`.
      UI brand-selection: investigated and found **no code change was needed**. The only
      brand-selection UI (`PairingManualAddSection`'s dropdown,
      `pairing_page_sections.dart:391`) iterates `TvBrand.values` generically and renders
      `brand.displayName` — Sony already appears automatically since A1 added the enum value.
      Confirmed via repo-wide search (`grep` for icon-mapping functions/asset paths) that
      **no per-brand icon system exists anywhere in this codebase** — every other
      brand (Samsung/LG/Hisense/AndroidTv/Roku/TCL) is also text-only in this dropdown, no
      icon assets, no fallback-icon mechanism to mirror. This is not a Sony-specific gap;
      flagging it as an **open item** rather than inventing one: if per-brand icons are ever
      wanted for the picker, that's a cross-brand UI feature, not something scoped to this
      adapter's rollout.
      Also checked `pairing_progress_hint_registry.dart` and `pre_pairing_steps_registry.dart`
      per this task's conditional instruction — both switch on `(TvBrand, protocolVariant)`
      tuples with a `_ => null` wildcard, so they are **not exhaustive** and `dart analyze`
      does not flag them; no `TvBrand.sony` case was required for compilation. At the time
      this note was written, Sony fell back to `null` (no hint/steps shown) pending
      on-device confirmation — **superseded 2026-08-24, see Decisions log**: real copy was
      researched and wired in as a same-day follow-up, ahead of A6.
      `dart analyze`: **0 issues** after the DI edit (no other switches broke — all
      `TvBrand`-exhaustive switches were already closed out in A3). Deps: A2, A3. Risk: LOW.
      Skills: language-specific-implementation, framework-mastery.
- [x] **A5. Automated tests** — adapter behavior test (mirrors an existing TCL/AndroidTv
      adapter test), variant-registry resolution test, DI wiring smoke test. — **done
      2026-08-24.**
      Detail/findings: no brand actually has a `*_adapter_test.dart` file in this codebase —
      the real established convention (confirmed by inspection) is a `*_test_lane_test.dart`
      per brand (e.g. `android_tv_test_lane_test.dart`), each with its own private spy
      transport class. Added `test/.../adapters/sony_test_lane_test.dart` mirroring
      `android_tv_test_lane_test.dart` exactly (brand/variant identity, key-mapping,
      reachability probe, no-override-map confirmation). Added one case to the existing
      `variant_resolution_registry_test.dart` (Sony resolves to the default variant).
      `tv_capabilities_test.dart` already iterates `TvBrand.values` generically, so Sony was
      automatically covered with no edit needed. For the "DI wiring smoke test": no test file
      for `remote_control_di_config.dart` existed at all before this task (confirmed by
      search, not assumed) — wrote a new
      `test/lib/remote_control/configurations/remote_control_di_config_test.dart` using this
      repo's existing `SharedPreferences.setMockInitialValues({})` + `FakeLocalizedStrings`
      conventions (both already used elsewhere) to call the real `configure()` on a fresh
      `GetIt` instance and assert `TvReachabilityService.isReachable()` returns `true` for a
      `TvBrand.sony` device — a genuine regression guard that fails if `SonyAdapter` is ever
      dropped from either adapters-list literal. `dart analyze`: 0 issues. `flutter test`
      (full suite): 588 passed, 0 failed, 0 regressions.
      Deps: A2, A3, A4. Risk: LOW. Skills: test-creation-strategy, correctness-validation.
- [ ] **A6. `sony_validation_matrix.md` + on-device manual test runbook**, mirroring the
      shape of `samsung_validation_matrix.md`/`tcl_validation_matrix.md`. Use this pass to
      resolve the A2 app-link-override question and to probe for the Sony-specific
      reliability issues noted in verified fact #7 (reconnect/availability bugs).
      Deps: A4. Risk: LOW. Skills: test-creation-strategy, documentation-knowledge-transfer.

## Sub-goal B — Research Sony BRAVIA IP Control (spike, no code changes)

Builds on the research already done this session (verified facts #9-13); resolves the
remaining open questions before any Bravia code is written.

- [x] **B1. Resolve the unverified protocol details** — done 2026-08-24.
      pro-bravia.sony.net retried, still 403 (Wayback Machine attempt also blocked at the
      tool level). Resolved instead via direct read of `pybravia`'s source (`Drafteed/pybravia`,
      confirmed via GitHub API + PyPI as the actual package HA's `braviatv` integration
      imports), cross-checked against that integration's `config_flow.py`. See verified fact
      #10 and Decisions log for the full endpoint/auth-shape writeup, including a correction
      to this doc's prior "cookie-only" assumption.
      Deps: none. Risk: LOW (research only). Skills: api-design, dependency-safety-integration.
- [ ] **B2. Resolve the architecture/UX fit question** (open question #1): decide, with the
      user, how a Bravia-path Sony device gets selected/paired given neither protocol is
      silently auto-detectable — user-facing choice vs. some form of probe-based detection.
      Produce a written recommendation.
      Deps: B1. Risk: LOW (research/design only). Skills: system-design, ux-constraints-awareness,
      abstraction-domain-modeling.
- [ ] **B3. Write findings into a reference doc — target doc OPEN, decide at B3 time.**
      Originally scoped as a new Sony/Bravia-only doc (`references/guide-sony-bravia-ip-control.md`).
      2026-08-25: user questioned whether that's still the right shape, since the actual
      routing/flow logic now lives in code + this goal doc's Decisions log, not in a
      findings doc — proposed instead folding Bravia's protocol details (B1's `actRegister`/
      PIN-over-Basic-Auth/cookie findings) into a general **all-brands-and-variants TV protocol
      reference** so there's one place to return to for any brand's wire protocol, not just
      Sony's. Note for whoever resolves this at B3: no such combined doc exists today — the
      closest precedent is `guide-android-tv-remote-protocol.md`, which is scoped to one
      protocol, not all brands (Samsung/LG/Hisense/Roku have no dedicated protocol guide at
      all, only validation matrices). Decide then: extend that precedent (a new
      `guide-sony-bravia-protocol.md`, one-per-protocol like Android TV's) vs. the user's
      combined-doc idea (bigger, first-of-its-kind artifact, would also mean backfilling or
      cross-referencing the brands that currently have none) — **decision checkpoint: present
      to the user for sign-off before any Sub-goal C task starts.**
      Deps: B1, B2. Risk: LOW. Skills: documentation-knowledge-transfer.

## Sub-goal C — Implement Sony BRAVIA IP Control adapter (placeholder, contingent on B)

**Do not start until B3 is signed off — task shapes below will likely change based on B2's
architecture decision (e.g., C1 assumes the protocol-variant mechanism applies; if B2
concludes it doesn't fit, this becomes a separate adapter/brand-selection path instead, closer
to TCL's model).**

- [ ] **C1. Add `sony_bravia` selection mechanism** per B2's decision (protocol-variant
      constant, or alternate mechanism). Deps: B3. Risk: MEDIUM.
      Skills: design-pattern-selection, abstraction-domain-modeling.
- [ ] **C2. Build `SonyBraviaTransportClient`** (HTTP/REST, `X-Auth-PSK` + PIN auth per B1
      findings). Deps: B3. Risk: MEDIUM. Skills: api-design, security, error-handling-resilience.
- [ ] **C3. Build `SonyBraviaAdapter`** implementing `TvBrandAdapter`. Deps: C1, C2. Risk:
      MEDIUM. Skills: language-specific-implementation, framework-mastery.
- [ ] **C4. Register variant-resolution entry (or equivalent) + DI wiring.** Deps: C1, C3.
      Risk: LOW. Skills: language-specific-implementation.
- [ ] **C4b. Build `ManualAddVariantProbe`** per the "B2 recommendation #3 superseded" decision
      log entry — derives candidates from the DI-built `List<TvBrandAdapter>` (already the source
      of truth for "which variants exist," see the "single source of truth" decision log entry —
      do not add a new static table), probes each candidate for `brand` via `probeConnection` in
      an explicit try-order still TBD (`brandIdentificationPriority` does NOT apply here — it's
      keyed by `TvBrand` only, and both of Sony's variants report `TvBrand.sony`, so it cannot
      order between a brand's own variants; needs its own small ordering, e.g. a private ordered
      list inside `ManualAddVariantProbe` itself), first success wins, `?? TvDevice.defaultProtocolVariant`
      if none respond; short-circuits to the single known variant (no I/O) for every brand except
      Sony. Wire into `_addManualDevice` (`pairing_page.dart:530`) above
      `PairingPageData.buildManualDevice(...)`. Deps: C3 (needs `SonyBraviaAdapter` to exist as a
      second candidate). Risk: MEDIUM. Skills: design-pattern-selection, api-design.
- [ ] **C5. `TvCapabilities` override if capabilities differ** from the Google TV path
      (e.g. Bravia's richer input-switching/app-launch catalog per verified fact #11). Deps:
      C3. Risk: LOW. Skills: abstraction-domain-modeling.
- [ ] **C6. Tests + validation matrix updates** for Bravia pairing (PSK entry flow, PIN
      flow) and command dispatch. Deps: C3, C4, C5. Risk: MEDIUM. Skills:
      test-creation-strategy, correctness-validation.

---

## Decisions log

- 2026-08-25: **B2 recommendation #3 superseded — probe-resolve at manual-add instead of a new
  UI; confirmed gap in `_addManualDevice` first.** Verified the actual current behavior (it was
  an assumption, not yet confirmed, when recommendation #3 below was written): `_addManualDevice`
  (`pairing_page.dart:530-543`) picks `protocolVariant` via a static switch (TCL's one hardcoded
  exception, else always `TvDevice.defaultProtocolVariant`) with **zero network I/O**, then hands
  the device straight to `_pairSelectedDevice` → `preparePairing` → `_adapterFor(brand, variant)`.
  For a manually-added Sony device today this always resolves to `SonyAdapter` (Google TV path) —
  there is no path by which a Bravia-only TV could ever be reached this way. Confirmed real gap,
  not specific to Sony (any future brand with >1 variant would hit the same thing).
  - **Rejected fix: a brand+variant picker UI** (the original recommendation #3). Superseded
    because there's a safer alternative that needs no new UI at all.
  - **Chosen fix: probe, don't ask.** Every `TvBrandAdapter` already implements
    `probeConnection({required TvDevice device})` (`tv_brand_adapter.dart:26`), and every existing
    implementation (`android_tv_tcp_transport_client.dart:211-218`, shared by
    AndroidTv/Sony/LG/Samsung/Hisense) is a **raw TCP connect + immediate close, 3s timeout** — no
    protocol handshake, no registration call, no PIN triggered. This is already relied on in
    production via `AdapterTvReachabilityService.isReachable` (`adapter_tv_reachability_service.dart`).
    B1's research established that Bravia's PIN display is triggered specifically by the
    `actRegister` call, not by opening a TCP connection — so a bare-connect probe for the future
    `SonyBraviaAdapter` is safe by the same reasoning already relied on for every other brand.
  - **New component, not bolted onto either existing resolver:**
    ```dart
    abstract interface class ManualAddVariantProbe {
      Future<String> resolve({required TvBrand brand, required String host});
    }
    ```
    Candidates for `brand` come from the DI-built `List<TvBrandAdapter>` (already the source of
    truth for "which variants exist" — every real variant needs an adapter to do anything, so the
    adapter list already declares them; see the "single source of truth" entry below), filtered to
    `adapters.where((a) => a.brand == brand)`. **Correction, 2026-08-25:** try-order between a
    brand's own variants is NOT `DiscoveredDeviceSupport.brandIdentificationPriority` — that
    function is keyed by `TvBrand` only (`discovered_device_support.dart:31-39`), and both of
    Sony's variants report `brand => TvBrand.sony`, so it returns one number for both and cannot
    order between them. It only orders *different brands* colliding on one host during discovery
    dedup — unrelated to this problem. Nothing in the codebase encodes intra-brand variant
    preference today; this needs its own small explicit ordering (e.g. a private ordered list
    inside `ManualAddVariantProbe` itself — Google TV path before Bravia is the likely choice, but
    not yet decided). `probeConnection` is called on a throwaway `TvDevice` per candidate in that
    order; first success wins; `?? TvDevice.defaultProtocolVariant` if none respond. Called from
    `_addManualDevice`, directly above `PairingPageData.buildManualDevice(...)`, same shape as the
    other two resolvers' `final variant = ... ?? fallback` call sites.
  - **Rejected: bolting this onto `DiscoveryVariantResolutionRegistry` or `VariantResolutionRegistry`.**
    Neither fits — `DiscoveryVariantResolutionRegistry` is a pure synchronous lookup with zero I/O
    (load-bearing to its contract, see its class doc), and `VariantResolutionRegistry.resolve`
    needs a live `TvDeviceInfo` that doesn't exist yet at manual-add time. This is a third,
    genuinely distinct resolution moment (see the "three resolvers, one concern" entry above this
    one for why keeping them separate is correct, not a smell).
  - **Guardrail: only probe when a brand actually has >1 known variant.** For every brand except
    Sony (once Bravia ships), there's exactly one candidate — probing unconditionally would add
    real network latency to manual-add for brands with nothing to disambiguate, a behavior change
    nobody asked for. `ManualAddVariantProbe` must short-circuit to the single known variant (no
    I/O) when there's only one, mirroring `DefaultVariantResolutionRegistry._entriesByBrand`'s
    "no entry needed for brands with nothing special" rule.
  - **Honest caveat:** a bare TCP-connect probe confirms "something is listening on this port,"
    not "this exact protocol is behind it" — same class of risk `probeConnection` already accepts
    everywhere else in the app today (not a new risk category). Worth a deliberate look at C2 to
    make sure Bravia's probe target doesn't collide with an unrelated service on typical home
    networks.
  - **Status: designed, not yet implemented** — planning only, per the user's explicit instruction
    this session. Implementation is a Sub-goal C task (see task list): needs `SonyBraviaAdapter`
    (C3) to exist as a second candidate before there's anything to probe against.
- 2026-08-25: **Three variant-resolution mechanisms confirmed as correct, not a smell to fix.**
  The user raised, and asked to resolve if possible: `DiscoveryVariantResolutionRegistry`
  (discovery-time, sync, zero I/O, keyed by discovery source), `VariantResolutionRegistry`
  (behavioral, sync, keyed by live `TvDeviceInfo` post-first-contact), and the new
  `ManualAddVariantProbe` above (async, does its own I/O, keyed by active per-IP protocol probing)
  are three separate interfaces answering what sounds like one question — "what's this device's
  `protocolVariant`?" — and asked whether clean-code/SOLID/design-pattern reasoning supports
  merging them into one source of truth.
  - **Conclusion: no, merging would violate the same principles that justified splitting them in
    the first place.** Each has a genuinely different input, timing, and mechanism — not an
    accidental duplication:
    | Resolver | When | Input | Mechanism |
    |---|---|---|---|
    | `DiscoveryVariantResolutionRegistry` | at discovery scan time, pre-first-contact | `(TvBrand, DiscoverySource?)` | sync map lookup, zero I/O |
    | `VariantResolutionRegistry` | at pairing time, post-first-contact | `(TvBrand, TvDeviceInfo?)` | sync predicate match against already-fetched data |
    | `ManualAddVariantProbe` | at manual-add time, pre-first-contact | `(TvBrand, host)` | async, does its own network I/O per candidate |
    A single merged interface would force every caller to depend on parameters and code paths it
    never uses (ISP violation) and give the merged class three unrelated reasons to change (SRP
    violation — a new discovery-source enum value, a new info-based dialect rule, and a probe
    timeout tweak are orthogonal concerns). This is the same reasoning that already justified
    keeping `DiscoveryVariantResolutionRegistry` separate from `VariantResolutionRegistry`
    earlier this session — `ManualAddVariantProbe` is a third instance of the same principle, not
    a new problem.
  - **Corrected, 2026-08-25: the "which variants exist for a brand" catalog already exists — no
    new shared file needed.** Initially proposed a new pure-data table (`TvBrand -> List<String>`)
    as the one shared reference point; on reflection this was wrong, because that fact is already
    single-sourced. The DI-built `List<TvBrandAdapter>` (`remote_control_di_config.dart:164-172`)
    already is that catalog — every real variant requires an adapter to do anything at all, so an
    adapter's `(brand, protocolVariant)` pair already declares "this variant exists."
    `BrandRoutedRemoteCommandService` already builds its dispatch map straight from that list
    (`{for (final a in adapters) (a.brand, a.protocolVariant): a}`); `ManualAddVariantProbe` should
    do the same (`adapters.where((a) => a.brand == brand)`) rather than introduce a second,
    parallel list that could drift out of sync with what's actually registered. Note: this list is
    not currently a registered `sl` singleton — it's a local variable built inline in the DI
    config and passed once to `BrandRoutedRemoteCommandService`; reusing it for
    `ManualAddVariantProbe` means constructing both from that same local variable in the same DI
    block, not adding a new singleton type. Confirmed separately: discovery does **not** need this
    list at all — `SsdpDeviceDiscoveryService`/`MdnsDeviceDiscoveryService`/
    `RokuSsdpDiscoveryService`/`CompositeDeviceDiscoveryService` take zero adapter dependencies,
    only `discoveryVariantRegistry` (pure config) — discovery-time resolution only needs to answer
    "what string goes into `protocolVariant`," which never required the adapter's actual behavior.
    The one thing that genuinely doesn't exist anywhere yet, and is the only new data actually
    needed: **preference order between a brand's own variants** (see the correction in the entry
    above — `brandIdentificationPriority` can't do this, it's keyed by brand only). That's small
    enough to live as a private ordered list inside `ManualAddVariantProbe` itself, same as
    `_entriesByBrand`/`_discoveryEntries` are each self-contained inside their own resolver — not
    worth its own file. Decide the actual ordering at C4b time (Google TV path before Bravia is
    the likely default, matching the existing "Google TV path as primary" intent elsewhere in this
    doc, but not yet a firm decision).
  - **Rejected: a coordinator/facade over all three resolvers.** No call site today is confused
    about which of the three to call — each already calls exactly one, at exactly one moment
    (scanners call discovery-time, `preparePairing` calls behavioral, `_addManualDevice` will call
    the prober). A facade would solve a problem that doesn't exist, purely to make "three things"
    look like "one thing" — overengineering, not simplification.
- 2026-08-25: **B2 recommendation #1 superseded — no bypass needed, it's a plain data addition.**
  The original B2 recommendation (below, 2026-08-24) said the Sony SSDP fingerprint should stamp
  `protocolVariant = SonyProtocolVariants.braviaIpControl` "directly when constructing the
  `TvDevice`, bypassing the predicate registry for this one case." That predated the discovery-time
  variant resolution mechanism (IMPLEMENTED entry below) and is now wrong: there is no bypass.
  Once Sub-goal C adds (a) a Sony fingerprint to `inferSsdpTvBrand` and (b) the actual
  `SonyProtocolVariants.braviaIpControl` constant + `SonyBraviaAdapter`, wiring the resolution is
  exactly one line added to `DefaultDiscoveryVariantResolutionRegistry._discoveryEntries`
  (`discovery_variant_resolution_registry.dart:28`):
  ```dart
  (TvBrand.sony, DiscoverySource.ssdp): SonyProtocolVariants.braviaIpControl,
  ```
  `SsdpDeviceDiscoveryService` already calls `discoveryVariantRegistry.resolveFromDiscovery(brand:
  candidate.brand, source: DiscoverySource.ssdp)` for every candidate, Sony included — no
  brand-specific special-casing in the scanner itself, same as every other brand. This is exactly
  the "pure data addition, zero ripple" property the mechanism was built for. Confirmed by the
  user; no other B2 recommendation changed by this entry.
- 2026-08-25: **Discovery-time variant resolution — IMPLEMENTED**, per the finalized design in
  the entry below. All six points shipped as designed, with one correction found during
  implementation:
  - **Correction: `discoveryVariantRegistry` is a `required` named parameter on all three
    scanners (`SsdpDeviceDiscoveryService`, `MdnsDeviceDiscoveryService`,
    `RokuSsdpDiscoveryService`), not defaulted to
    `const DefaultDiscoveryVariantResolutionRegistry()`** as the design entry's code sketch
    originally showed. Grepped every construction site before implementing and confirmed the
    default would have been dead code — both DI graphs (`remote_control_di_config.dart`) already
    pass it explicitly, and no test constructs any of these three scanners bare. Keeping an
    unused default while also forcing explicit DI everywhere was redundant and inconsistent with
    how `VariantResolutionRegistry` is already injected into `BrandRoutedRemoteCommandService`
    (`required this.variantRegistry`, no default) — injected collaborators are `required` in
    this codebase, only scalar config like `timeout` gets a default.
  - `RokuSsdpDiscoveryService` also got the same treatment (stamps `DiscoverySource.roku`),
    for consistency — the design entry only explicitly walked through Ssdp/Mdns.
  - `_discoveryEntries` in `DefaultDiscoveryVariantResolutionRegistry` shipped **empty**. Sony's
    `(TvBrand.sony, DiscoverySource.ssdp) → braviaIpControl` mapping used throughout the design
    discussion was illustrative, not real yet — there's no SSDP fingerprint for Sony in
    `inferSsdpTvBrand` and no Bravia adapter registered (Sub-goal C, not started), so adding that
    entry now would be dead/unreachable code with no backing implementation. The mechanism is
    fully wired and tested; the first real entry lands with Sub-goal C.
  - Verified: `flutter analyze` clean, `dart format` clean, full suite passes (592 tests, 0
    failures) after updating `variant_resolution_registry_test.dart`'s now-null-returning
    expectations and `brand_routed_remote_command_service_test.dart`'s `_StubVariantRegistry`
    signature; added `discovery_variant_resolution_registry_test.dart` for the new class.
  - Files actually touched: new `discovery_source.dart`, new
    `discovery_variant_resolution_registry.dart`, `data.dart` (barrel export),
    `ssdp_device_discovery_service.dart`, `mdns_device_discovery_service.dart`,
    `roku_ssdp_discovery_service.dart`, `variant_resolution_registry.dart`,
    `brand_routed_remote_command_service.dart`, `remote_control_di_config.dart`, plus the three
    test files above. `tv_device.dart` and `composite_device_discovery_service.dart` untouched,
    as designed.
- 2026-08-25: **Discovery-time variant resolution — design FINALIZED (supersedes three points in
  the "design settled through iteration" entry below), still NOT IMPLEMENTED.** The root-cause
  diagnosis, the rejection of embedding `DiscoverySource` in `TvDeviceInfo`, and the "structural
  vs. behavioral" framing in the entry below all still stand — only the *shape* of the fix
  changed, via further live code-level review of that entry's own snippets:
  1. **Two separate interfaces, not one interface with two methods.** The entry below deliberately
     kept `resolveFromDiscovery` as a second method on the existing `VariantResolutionRegistry`
     rather than a new interface, to avoid ceremony. Re-examined: no consumer ever needs both
     methods (`preparePairing()` only calls `resolve(info:)`; discovery only calls
     `resolveFromDiscovery`) — forcing them onto one interface is a real ISP violation, not just
     ceremony-avoidance, and it's the same structural/behavioral split that motivated this whole
     redesign, applied one level deeper to the resolvers themselves:
     ```dart
     abstract interface class VariantResolutionRegistry {
       String? resolve({required TvBrand brand, required TvDeviceInfo? info});
     }
     abstract interface class DiscoveryVariantResolutionRegistry {
       String resolveFromDiscovery({required TvBrand brand, required DiscoverySource? source}); // non-nullable — see #2
     }
     ```
  2. **`resolveFromDiscovery` returns non-nullable `String`, baking in the
     `TvDevice.defaultProtocolVariant` fallback internally** — the opposite of `resolve(info:)`,
     deliberately. `resolve(info:)` had to go nullable because it's a *second write*: it can run
     on a device whose `protocolVariant` already holds something meaningful from discovery, so it
     needs a way to say "no opinion, don't touch what's there." `resolveFromDiscovery` is the
     *first write* — at the point it runs, `protocolVariant` is always still the constructor
     default, so "no rule matched" and "resolved to default" produce the identical outcome. No
     caller-side ambiguity exists to protect against, so there's no reason to make the caller
     handle a null case that can never carry meaning here:
     ```dart
     @override
     String resolveFromDiscovery({required TvBrand brand, required DiscoverySource? source}) =>
         _discoveryEntries[(brand, source)] ?? TvDevice.defaultProtocolVariant;
     ```
  3. **Resolution happens inline at scanner construction time, not a post-merge step in
     `CompositeDeviceDiscoveryService`.** The entry below modeled the new step as a sibling to
     `_enrichAndroidTvIdentity`, but that existing step is post-merge specifically *because it
     needs a live network probe* and wants to avoid probing pre-dedup duplicates — a constraint
     that doesn't apply here. `resolveFromDiscovery` is a pure, synchronous lookup over data each
     scanner already has at construction time (its own brand guess + its own fixed source), so
     there's no reason to defer it. It also matches the pattern already used one line above it in
     every scanner: `capabilities: const TvCapabilities().capabilitiesFor(candidate.brand)`.
     ```dart
     // ssdp_device_discovery_service.dart
     class SsdpDeviceDiscoveryService implements DeviceDiscoveryService {
       SsdpDeviceDiscoveryService({
         required this.discoveryVariantRegistry, // required, not defaulted — see implementation entry above
         this.timeout = const Duration(seconds: 3),
       });
       final DiscoveryVariantResolutionRegistry discoveryVariantRegistry;
       // ...
       TvDevice(
         // ...
         protocolVariant: discoveryVariantRegistry.resolveFromDiscovery(
           brand: candidate.brand,
           source: DiscoverySource.ssdp,
         ),
         capabilities: const TvCapabilities().capabilitiesFor(candidate.brand),
         host: candidate.ip,
       );
     }
     ```
     Same shape in `MdnsDeviceDiscoveryService` (`source: DiscoverySource.mdns`).
  4. **Consequence: `TvDevice.discoverySource` is no longer needed at all — dropped from the
     plan.** That field's only purpose in the entry below was to carry "which scanner found this"
     forward from scanner-time to a later post-merge step. Once resolution happens inline, each
     scanner already knows its own source (a hardcoded constant per class) and never needs to
     stash it for a later stage to read back. Confirmed no other consumer needs it either — the
     diagnostics wrapper (`DiagnosticsRecordingDeviceDiscoveryService`) only logs aggregate counts,
     not per-device provenance. This removes `tv_device.dart` and
     `composite_device_discovery_service.dart` from the touch-list entirely.
  5. **`brand_routed_remote_command_service.dart`'s `preparePairing()` — the one line that
     actually fixes the original clobbering bug.** Everything else in this design exists to make
     this one substitution safe. Before (current code, `brand_routed_remote_command_service.dart:69`):
     ```dart
     final variant = _variantRegistry.resolve(brand: device.brand, info: info);
     ```
     After:
     ```dart
     final refined = _variantRegistry.resolve(brand: device.brand, info: info);
     final variant = refined ?? device.protocolVariant;
     ```
     (`refined` and `variant` are just names for the intermediate nullable result and the final
     fallback-applied value — functionally identical to writing it as one inlined line.)
     No other line in this method changes — `_adapterFor(device.brand, device.protocolVariant)`
     at line 60 (top of the method) is untouched, since by the time `preparePairing()` runs, the
     adapter selection already happened using whatever `protocolVariant` discovery (or manual-add)
     already assigned; this line only affects what gets persisted going forward via `enriched`.
     Ripple effect: `VariantResolutionRegistry.resolve()`'s signature itself changes to `String?`
     (point 1 above), so every existing test double implementing that interface
     (`variant_resolution_registry_test.dart`,
     `brand_routed_remote_command_service_test.dart` fakes) needs its `resolve` override's return
     type updated from `String` to `String?` too, or the build breaks at the implementation site,
     not silently.
  6. **`variant_resolution_registry.dart` itself — the other half of point 5's fix, spelled out in
     full (this is what makes `?? device.protocolVariant` safe to rely on).** Nullable return type
     on both the interface and impl, `resolve()`'s body returns `null` instead of
     `TvDevice.defaultProtocolVariant` at every "no match" branch, and — since "no entry" and
     "resolves to null" now mean the same thing — every brand whose only job was restating the
     constructor default (`lg`, `samsung`, `hisense`, `androidTv`, `roku`, `sony`) drops out of
     `_entriesByBrand` entirely. TCL is the one exception that stays, since `TclGoogleTvAdapter`
     isn't registered and `default` has no adapter for that brand — its catch-all is load-bearing,
     not decorative:
     ```dart
     abstract interface class VariantResolutionRegistry {
       String? resolve({required TvBrand brand, required TvDeviceInfo? info});
     }

     class DefaultVariantResolutionRegistry implements VariantResolutionRegistry {
       const DefaultVariantResolutionRegistry();

       // Only brands with a genuine info-based dialect rule need an entry. No entry
       // ("no opinion") is correct for every other brand — the caller falls back to
       // device.protocolVariant, which is already correct (constructor default, or
       // whatever discovery-time resolution already stamped).
       static final Map<TvBrand, List<_VariantResolutionEntry>> _entriesByBrand = {
         // ── TCL (legacy Wi-Fi only; no default-variant adapter registered) ─────
         TvBrand.tcl: [
           _VariantResolutionEntry(
             matches: TclProtocolVariants.isLegacyWifi,
             variant: TclProtocolVariants.legacyWifi,
           ),
           _VariantResolutionEntry(
             matches: (_) => true,
             variant: TclProtocolVariants.legacyWifi,
           ),
         ],
       };

       @override
       String? resolve({required TvBrand brand, required TvDeviceInfo? info}) {
         if (info == null) return null;
         final entries = _entriesByBrand[brand];
         if (entries == null) return null;
         for (final entry in entries) {
           if (entry.matches(info)) return entry.variant;
         }
         return null;
       }
     }
     ```
     `_VariantResolutionEntry` itself is unchanged from the already-implemented map-grouping pass
     (see the "Map-grouped `_entries` implemented" entry below) — only `resolve()`'s return
     statements and `_entriesByBrand`'s brand list change here.
  - **Updated file list for implementation:** new file(s) for the `DiscoverySource` enum
    (`{ ssdp, mdns, roku }`) and `DiscoveryVariantResolutionRegistry` /
    `DefaultDiscoveryVariantResolutionRegistry`; `ssdp_device_discovery_service.dart`;
    `mdns_device_discovery_service.dart`; `variant_resolution_registry.dart` (nullable
    `resolve()` return type — already map-grouped, see entry below — plus deleting the now-dead
    catch-all entries for every brand except TCL, whose catch-all is load-bearing since
    `TclGoogleTvAdapter` isn't registered and `default` has no adapter for that brand);
    `brand_routed_remote_command_service.dart` (`preparePairing()` becomes
    `_variantRegistry.resolve(brand: device.brand, info: info) ?? device.protocolVariant`);
    `remote_control_di_config.dart` — register `DiscoveryVariantResolutionRegistry` as a
    singleton (mirrors `VariantResolutionRegistry`'s existing registration at lines 59-60) and
    inject it explicitly into both `SsdpDeviceDiscoveryService(...)`/
    `MdnsDeviceDiscoveryService(...)`/`RokuSsdpDiscoveryService(...)` construction call sites
    (there are two — a real-build graph and a debug-build graph, both previously constructing
    these scanners with no args) — the scanner constructors take it as a `required` named
    parameter, not a defaulted one, matching how `VariantResolutionRegistry` is already injected
    into `BrandRoutedRemoteCommandService` (no default there either); a default was considered
    and rejected during implementation, see the entry above — plus tests. `tv_device.dart` and
    `composite_device_discovery_service.dart` need **no changes**.
  - **Status: IMPLEMENTED — see the entry above.**
- 2026-08-25: **Map-grouped `_entries` implemented** — the "Performance shape" bullet below is
  now done. `DefaultVariantResolutionRegistry._entriesByBrand` is declared directly as a
  `Map<TvBrand, List<_VariantResolutionEntry>>` literal (no intermediate flat list or grouping
  helper — written as a map from the start, one entry-list per brand), and `resolve()` does an
  O(1) brand lookup before its short per-brand scan instead of scanning every entry regardless
  of brand. Since the map key now carries the brand, `_VariantResolutionEntry.brand` was dead
  weight (nothing read it after grouping) and was dropped — entries now only carry `matches` and
  `variant`. Interface (`resolve({brand, info})`) and behavior are unchanged — verified via
  `flutter analyze` (clean) and the existing `variant_resolution_registry_test.dart` +
  `brand_routed_remote_command_service_test.dart` suites (61 tests, all passing), so no
  call-site or test updates were needed. Everything else in the entry below (`discoverySource`
  field, `resolveFromDiscovery`, the nullable `String?` return-type fix) is **still not
  implemented** — this only closes the performance sub-point.
- 2026-08-25: **Discovery-time variant resolution — design settled through iteration, NOT YET
  IMPLEMENTED.** ⚠️ **Partially superseded by the entry above** (two interfaces instead of one,
  non-nullable `resolveFromDiscovery`, construction-time instead of post-merge, no
  `discoverySource` field) — the root-cause diagnosis and the `TvDeviceInfo`-rejection reasoning
  below still stand, but skip the `discoverySource` field and the post-merge-step code sketch,
  they're stale. This refines/supersedes the B2 recommendation below with a design worked out
  interactively (not yet coded — recording in full so the design survives even if the coding
  session that resumes this forgets the reasoning):
  - ~~`TvDevice` gets a new `discoverySource` field (`enum DiscoverySource { ssdp, mdns, roku }`,
    nullable) — **transient, not persisted to `SharedPreferences`/JSON.** Each discovery
    scanner (`ssdp_device_discovery_service.dart`, `mdns_device_discovery_service.dart`) stamps
    its own provenance with zero brand-variant knowledge — no scanner ever imports a
    `*ProtocolVariants` class.~~ — superseded, see entry above (#4): no field needed at all.
  - `VariantResolutionRegistry` gets a **second, separate method** rather than widening the
    existing `matches` predicate signature — rejected adding `DiscoverySource` as a parameter
    to `bool Function(TvDeviceInfo info) matches` because `TvDeviceInfo` (adapter-probe output,
    only available post-first-contact) and `DiscoverySource` (scanner output, only available
    pre-first-contact) are never live at the same time — cramming both into one predicate
    signature would leave every existing predicate carrying a parameter it never uses:
    ```dart
    abstract interface class VariantResolutionRegistry {
      String? resolve({required TvBrand brand, required TvDeviceInfo? info});             // ← changes to nullable, see below
      String? resolveFromDiscovery({required TvBrand brand, required DiscoverySource? source}); // new
    }
    ```
  - **Rejected putting `discoverySource` inside `TvDeviceInfo` itself** — `TvDeviceInfo` has one
    documented provenance (`guide-protocol-variants.md`'s field table: "Source:
    `queryDeviceInfo` → adapter"), meaning after an adapter is already selected and already
    communicating. `discoverySource` exists before any adapter is chosen at all. Merging them
    would reproduce, one level deeper, the exact same conflation this whole design exercise
    exists to fix (see next bullet).
  - **The actual root problem, restated precisely:** `TvDevice.protocolVariant` conflates a
    **structural** decision (which adapter/transport — must be correct before first contact,
    since `BrandRoutedRemoteCommandService.preparePairing` selects the adapter via
    `device.protocolVariant` *before* calling `queryDeviceInfo()`,
    `brand_routed_remote_command_service.dart:60`) with a **behavioral** decision (which dialect
    within an already-fixed transport — safely refinable after first contact, e.g. a
    hypothetical Samsung Frame case). The existing `VariantResolutionRegistry.resolve()` was
    built only for the behavioral job. Fixing this without a full field-split migration (real
    cost: the guide explicitly warns the variant string is persisted to `SharedPreferences` and
    must never be renamed once shipped) means: resolve the structural half at discovery time
    (new `resolveFromDiscovery`, called once per device from a new post-merge step in
    `CompositeDeviceDiscoveryService`, sibling to the existing `_enrichAndroidTvIdentity`), and
    leave the behavioral half (`resolve(info:)`) exactly where and how it already runs, inside
    `preparePairing()`.
  - **Performance shape, addressed but not the main point:** `resolve()`'s existing `_entries`
    is a flat list scanned linearly regardless of brand — restructuring to
    `Map<TvBrand, List<_VariantResolutionEntry>>` (grouped once, looked up O(1), then a short
    per-brand scan) removes wasted cross-brand comparisons. `resolveFromDiscovery`'s table
    doesn't need predicates or `_VariantResolutionEntry` at all — `DiscoverySource` is a small
    closed enum (exact match only, never a pattern like `model.startsWith(...)`), so it's a
    flat `Map<(TvBrand, DiscoverySource?), String>` lookup. Both are internal to
    `DefaultVariantResolutionRegistry` — callers only ever see the abstract interface, so this
    is a zero-ripple internal change.
  - **Open, unresolved smell — do not implement the naive version:** `preparePairing()` calls
    `resolve(info:)` *after* discovery already set a structural variant via
    `resolveFromDiscovery` — e.g. Sony resolved to `braviaIpControl` at discovery time. Sony's
    only entry in the info-based table is the plain catch-all
    (`variant: TvDevice.defaultProtocolVariant`), so a naive second call would silently reset
    the device back to the default (Android TV) variant on every pairing attempt, undoing the
    discovery-time resolution. A same-turn fix using value-equality
    (`refined == TvDevice.defaultProtocolVariant ? device.protocolVariant : refined`) was
    proposed and **rejected as smelly**: it overloads a real domain constant
    (`TvDevice.defaultProtocolVariant`) to also mean "no match found," which is exactly the
    ambiguity nullable types exist to avoid — a future brand that legitimately needs "explicitly
    resolved to default" to mean something different from "nothing matched" would silently
    break with no compiler warning. **Correct fix, not yet implemented:** change
    `resolve()`'s return type to `String?` (`null` = no match), so
    `preparePairing()` becomes `_variantRegistry.resolve(brand: device.brand, info: info) ??
    device.protocolVariant` — an honest optional instead of a sentinel-value hack. This is a
    real interface-signature change (return type, not just a call-site tweak) and needs its own
    deliberate pass, including updating every existing call site/test that currently expects a
    non-nullable `String` back from `resolve()`.
  - ~~**Status: fully designed through iteration, zero code written yet.** Files that will need
    touching when this is implemented: `tv_device.dart` (new field),
    `ssdp_device_discovery_service.dart`, `mdns_device_discovery_service.dart` (stamp
    provenance), `variant_resolution_registry.dart` (map-grouped entries, new method, nullable
    return type), `composite_device_discovery_service.dart` (new post-merge step + registry
    injected into its constructor + the one DI call site), `brand_routed_remote_command_service.dart`
    (`preparePairing()`'s `??` fix) — plus tests for the new discovery-based lookup, the
    grouped-map behavior, and the non-clobbering composition of the two `resolve` calls.~~ —
    **stale, see the finalized file list in the entry above.**
- 2026-08-24: **B2 — architecture/UX fit for Bravia-path selection, pending user sign-off**
  (open question #1). Research + direct code reads:
  - **Medium-high confidence:** Sony BRAVIA IP Control is independently SSDP-discoverable —
    Home Assistant's `braviatv` integration matches on manufacturer `Sony Corporation` +
    search-target `urn:schemas-sony-com:service:ScalarWebAPI:1`
    (`homeassistant/components/braviatv/manifest.json`,
    https://github.com/home-assistant/core/blob/dev/homeassistant/components/braviatv/manifest.json).
    This app's own `inferSsdpTvBrand` (`ssdp_brand_inference.dart:30-49`) has no Sony
    fingerprint yet — only roku/samsung/lg/hisense/androidtvremote are matched.
  - **Low confidence, unresolved:** whether the TV's SSDP responder is active before the
    user enables "IP Control" in TV settings, or only after. No primary source found either
    way this session — a real caveat for how reliable SSDP-only discovery is in practice.
  - **High confidence, direct code read:** the existing `queryDeviceInfo →
    VariantResolutionRegistry.resolve` mechanism (`guide-protocol-variants.md`) cannot
    be used to choose between Sony's two protocols. `BrandRoutedRemoteCommandService
    .preparePairing` (`brand_routed_remote_command_service.dart:57-68`) resolves the adapter
    via `_adapterFor(device.brand, device.protocolVariant)` **before** calling
    `adapter.queryDeviceInfo()` — so by the time `TvDeviceInfo` exists, an adapter (and
    therefore a transport/protocol) has already been invoked. `TvDevice.protocolVariant`
    defaults to `defaultProtocolVariant` in the model constructor
    (`tv_device.dart:32`) and neither `SsdpDeviceDiscoveryService` nor
    `MdnsDeviceDiscoveryService` overrides it today — every discovered device gets the
    default variant regardless of discovery source. **Conclusion: the discovery-protocol
    signal must be stamped onto `TvDevice.protocolVariant` by the scanner itself, at
    construction time** — not routed through `TvDeviceInfo` (rejects the user's alternative
    proposal of adding a network-protocol field to `TvDeviceInfo`, since that data arrives
    one step too late in the pipeline to influence adapter selection).
  - **Recommendation (pending sign-off):**
    1. Add a Sony fingerprint to `inferSsdpTvBrand` (`ScalarWebAPI`/`Sony Corporation`
       match) that stamps `protocolVariant = SonyProtocolVariants.braviaIpControl` (new
       constant) directly when constructing the `TvDevice`, bypassing the predicate
       registry for this one case. mDNS-found Sony devices keep going through Sub-goal A's
       existing path (`androidtvremote2` → `androidTv` brand, unchanged).
    2. Merge-by-host collision (both protocols on one physical TV): no code change needed.
       `DiscoveredDeviceSupport.brandIdentificationPriority` already ranks
       `androidTv => 4` below `sony => 6` (`discovered_device_support.dart:31-39`), so
       `androidTv` wins the dedup automatically whenever both are found at the same IP —
       confirmed correct per the user's own reasoning this session, and matches the doc's
       already-stated intended default (Google TV path as primary).
    3. Manual add-by-IP: since no existing per-brand multi-variant UI precedent exists
       (TCL correction above), Sony's manual-add needs new UI — most likely two
       distinct selectable entries ("Sony (Google TV)" / "Sony (BRAVIA)") at the
       manual-add sheet level only (no `TvBrand` enum change), each hardcoding its
       respective variant the same way TCL's ternary does today. This is a real UX
       decision, not just an engineering default.
  - **Open per this recommendation:** exact UI copy/placement for #3, and whether SSDP's
    on/off-before-enabling-IP-Control gap (above) means manual add-by-IP is a required
    fallback (likely yes, until proven otherwise) or a nice-to-have.
- 2026-08-24: **B1 — BRAVIA PIN-pairing protocol resolved via direct source read of
  `pybravia`** (open question #2 closed). Findings:
  - **High confidence, direct source read:** pairing is `POST /sony/accessControl`,
    JSON-RPC method `actRegister`, version `"1.0"`:
    ```json
    {"method":"actRegister","params":[{"clientid":"<id>","nickname":"<name>","level":"private"},[{"value":"yes","function":"WOL"}]],"id":1,"version":"1.0"}
    ```
    — https://raw.githubusercontent.com/Drafteed/pybravia/master/pybravia/client.py
    (`register()`), const `SERVICE_ACCESS_CONTROL = "accessControl"` in
    https://raw.githubusercontent.com/Drafteed/pybravia/master/pybravia/const.py
  - **High confidence:** pairing-initiation and PIN-confirmation are the *same* call.
    Initiation sends a hardcoded dummy PIN (`"0000"`) purely to trigger the TV's on-screen
    PIN display, suppressing the resulting auth error; the real PIN is then sent via an
    identical second call. — same file, `pair()`/`register()`.
  - **High confidence — corrects this doc's prior assumption:** the PIN travels as **HTTP
    Basic Auth** (`Authorization: Basic base64(":"+pin)`), not in the JSON body. On success
    the TV returns a `Set-Cookie` header, but the client must keep sending **both** the
    cookie *and* the original Basic-Auth header on every subsequent request for the session's
    lifetime (only cleared on disconnect or switch to PSK) — verified in `send_req()`, same
    file. There is also a known non-RFC-compliant cookie quirk requiring manual normalization
    (`normalize_cookies()` in
    https://raw.githubusercontent.com/Drafteed/pybravia/master/pybravia/util.py, see
    https://github.com/Drafteed/pybravia/issues/1#issuecomment-1237452709).
  - **Medium confidence:** no protocol-generation branching exists for `actRegister` itself.
    The only generation-sensitive quirk found is IRCC endpoint casing (`/sony/IRCC` vs
    `/sony/ircc`, auto-detected on 404) — a display-model quirk, unrelated to pairing/auth.
  - **Low confidence, explicitly unconfirmed — do not build against this:** a web-search
    summary (not source code) claimed newer Bravia XR models reject `actRegister` v1.0.
    Searched pybravia's issues/repo directly and found no corroborating evidence. Flagged,
    not acted on.
  - **Cross-check, high confidence:** Home Assistant's `braviatv` integration calls
    pybravia's `pair()`/`connect(pin=...)` directly with no protocol reimplementation,
    confirming this is the shipped production flow, not a one-off implementation detail. —
    https://raw.githubusercontent.com/home-assistant/core/dev/homeassistant/components/braviatv/config_flow.py
  - **Still unresolved:** pro-bravia.sony.net remains blocked (403) as a primary source;
    a Wayback Machine retry was blocked at the tool level this session (not attempted, not
    just unsuccessful) — worth a retry from a different environment if Sony's own spec
    language is ever needed verbatim (e.g. for edge-case error codes).
- 2026-08-24: **Sony pairing hint/step copy researched and wired in, ahead of A6.**
  Research (real web search — Sony support pages, Google's Google TV help, Home Assistant's
  `androidtv_remote` integration docs and its upstream `tronikos/androidtvremote2` library;
  not internal-doc assumptions) found **no verified Sony-specific difference** from the
  generic Android TV Remote pairing flow: no Sony-specific setting/toggle to enable
  (medium-high confidence — an absence-of-evidence conclusion after multiple targeted
  searches), the PIN screen is rendered by Google's own system app so should look identical
  across OEMs (medium confidence — no direct screenshot comparison found), and Sony's own
  support site confirms the exact string "Android TV Remote Service" appears on Sony hardware
  (high confidence, https://www.sony.co.in/electronics/support/articles/00184278). One
  caveat, medium confidence: some *older, non-Google-TV* Bravia models reportedly lack this
  API entirely and need Sony's own app instead — not believed relevant to the 2021+ models
  this adapter targets, but not hard-ruled-out either. Given this, reused the Android TV copy
  verbatim with only the brand name swapped (per the standing "don't invent a difference to
  sound thorough" rule — [[feedback-verify-external-claims]]):
  - `pairingSonyPreStep0`: "Your Sony TV is ON and on the same Wi-Fi."
  - `pairingSonyPreStep1` / `pairingSonyProgressHint`: "A PIN will appear on your TV screen —
    enter it when prompted."

  Wired as `(TvBrand.sony, TvDevice.defaultProtocolVariant)` entries — **keyed by variant, not
  just brand**, matching this registry's existing design (see TCL's
  `(TvBrand.tcl, TclProtocolVariants.legacyWifi)` entry, which carries different copy from
  TCL's other variants). This matters going forward: Sub-goal C's Bravia variant will need
  its **own** distinct `(TvBrand.sony, <braviaVariant>)` entries once it ships, since Bravia's
  PSK/PIN-over-REST pairing flow is not the same UX as this on-screen 6-character code — reusing
  this Google-TV-path copy for Bravia would be actively misleading, not just imprecise.
  Added ARB entries (`lib/l10n/app_en.arb`) + regenerated via `flutter gen-l10n`, extended
  `LocalizedStrings`/`AppLocalizedStrings`/`FakeLocalizedStrings`, added one spot-check test
  per registry (matching the existing LG/Samsung per-brand test convention — neither registry
  test file exhaustively covers every brand). `dart analyze`: 0 issues. `flutter test`: 590
  passed, 0 failed. **A6 still held** for on-device confirmation that this copy matches what a
  real Sony Google TV actually shows during pairing.
- 2026-08-24: **Confirmed and accepted (user):** with no Sony-specific SSDP fingerprint
  added, a Sony TV on the Android TV Remote path will list as "Android TV," not "Sony," in
  the discovered-device list (verified fact #16) — consistent with TCL's existing behavior,
  not a regression. Given `androidTv`'s merge priority (4) already outranks lower-priority
  brand guesses like `tcl` (5) (verified fact #15), this also means: if a future
  Sony-specific SSDP signal (e.g. for the Bravia path) were ever ranked below `androidTv` in
  that table, the Android TV classification would win by default whenever both protocols are
  detected on the same physical device — which happens to match Sub-goal A's intended
  default (Google TV path as primary). No new task added for this; revisit only if the
  Sub-goal C "show both rows" work (open question #1) needs Sony to carry its own discovery
  identity to make that distinction visible.
- 2026-08-24: Split into 3 sub-goals (A: Google TV path now; B: Bravia research; C: Bravia
  implementation, gated on B) rather than one combined adapter effort — user's call, to keep
  the well-understood low-risk path from being blocked on the higher-uncertainty one.
- 2026-08-24: Rejected a model-year-based ("2021+ → Google, older → Bravia") detection
  scheme after research showed both protocols can coexist on the same modern hardware and
  neither is tied to a hard year cutoff (verified facts #8, #12). Replaced with open question
  #1, deferred to Sub-goal B2 rather than decided here.

## Done criteria

- Sub-goal A: Sony selectable as a brand in the app, pairs and controls a real 2021+ Sony
  Google TV device via the shared Android TV Remote protocol, tests passing, validation
  matrix filled in from real-device testing.
- Sub-goal B: written findings doc exists, open questions #1 and #2 resolved, user has
  signed off on Sub-goal C's task list.
- Sub-goal C: Bravia-path adapter working against a real Sony TV with IP Control enabled,
  tests passing, validation matrix updated.
