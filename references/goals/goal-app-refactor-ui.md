# Goal: App Refactor, Clean Code, and UI Improvements

**Goal ID:** `app-refactor-ui`
**Created:** 2026-04-22
**Status:** `pending`
**Owner:** wlvyr

---

## Goal Statement

Across four separate feature branches, address accumulated technical debt (folder structure,
SOLID violations, code smells), redesign the pairing page into a Remote Selection UI, and
improve the TV remote screen UX. Each branch is independently deliverable and mergeable.

---

## Decisions Log

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Target folder structure: `lib/app`, `lib/remote_control`, `lib/theme`, `lib/<feature_name>` — flat, no `src` wrapper, no `features/` namespace | Single-feature app; `features/` namespace adds noise without benefit; future features get `lib/<name>` |
| D2 | `lib/src/app` (app shell/routing) and `lib/src/features/remote_control/application` (service layer) are distinct concerns — both survive the rename, paths change | Naming confusion only; they are not duplicates |
| D3 | Include brand dispatch Strategy map (task 2.5) in refactor/solid-clean-code branch | Same root cause as `sendKey()` if/else; fix together while context is active |
| D4 | Disconnection detection: add `Stream<ConnectionState>` to transport interface; LG + Samsung use WebSocket `onDone`/`onError` (event-driven); Hisense uses periodic ping poll | Keeps brand logic below adapter boundary; UI subscribes to a unified stream |
| D5 | DI container: `get_it` + `injectable` for adapter/service wiring — each concern gets an `@module` class (direct analog to `IDIConfig<Container, AppSettings>`); `OneRemoteApp` becomes a pure widget; `@prod`/`@dev` env tags replace runtime `_useFakeTransports` branching | Widget should not own construction logic; modular DI makes transport swapping, testing, and new-brand onboarding explicit without touching the app shell |

---

## Branch 1 — `refactor/folder-structure` (done)

**Sub-goal:** Flatten `lib/` to feature-named top-level directories; remove `src` wrapper and `features/remote_control` nesting.

**Target structure:**
```
lib/
  app/            ← MaterialApp, routing, DI setup  (was lib/src/app)
  remote_control/ ← full feature (was lib/src/features/remote_control)
    application/  ← services / use-cases
    data/         ← adapters, transport clients
    domain/       ← models
    presentation/ ← pages, widgets
    debug/
  theme/          ← (was lib/src/theme)
  main.dart
```

| ID | Task | Skills | Deps | Risk |
|----|------|--------|------|------|
| 1.1 | Document approved target structure and all affected import paths | `abstraction-domain-modeling`, `modularity` | — | LOW |
| 1.2 | Rename/move directories to target structure | `refactoring` | 1.1 | MEDIUM |
| 1.3 | Update all Dart imports across `lib/` and `test/` | `refactoring`, `framework-mastery` | 1.2 | MEDIUM |
| 1.4 | Flatten `test/lib/` internals to mirror new `lib/` layout — remove `src/features/remote_control/` nesting so paths become e.g. `test/lib/remote_control/data/…`, `test/lib/remote_control/application/…` (`test/lib/` wrapper stays) | `refactoring` | 1.2 | MEDIUM |
| 1.5 | Run `flutter build` + full test suite; fix any broken references | `framework-mastery`, `regression-prevention` | 1.3, 1.4 | MEDIUM |

---

## Branch 2 — `refactor/solid-clean-code`

**Sub-goal:** Eliminate SOLID violations, duplicated toggle-state boilerplate, growing brand dispatch chains, raw error exposure, and introduce a DI container to decouple service construction from the presentation layer.

> **Depends on Branch 1 being merged** (import paths must be stable before refactoring internals).

> ⚑ Tasks marked *Tentative* were surfaced during lib review (`references/refactor-proposal.md`) and are up for debate — confirm before scheduling.

| ID | Task | Skills | Deps | Risk |
|----|------|--------|------|------|
| 2.1 | Audit entire `lib/` for SOLID violations, code smells, and duplication — produce prioritised findings list | `clean-code-solid`, `complexity-analyzer`, `technical-debt-management` | — | LOW |
| 2.2 | Write unit tests covering current behaviour in all areas flagged by 2.1 (safety net before any refactor) | `test-creation-strategy` | 2.1 | MEDIUM |
| 2.3 | Replace `LgWebSocketTransportClient.sendKey()` if/else chain with a command dispatch map | `design-pattern-selection`, `clean-code-solid` | 2.2 | MEDIUM |
| 2.4 | Unify `_muteStates`, `_powerStates`, `_playingStates` into a single generic toggle-state abstraction | `abstraction-domain-modeling`, `refactoring` | 2.2 | MEDIUM |
| 2.5 | Replace growing brand if/else in `BrandRoutedRemoteCommandService` with Strategy map keyed by `TvBrand` | `design-pattern-selection`, `clean-code-solid` | 2.2 | MEDIUM |
| 2.6 | Apply `kDebugMode` guard to all 4 `catch` blocks in `BrandRoutedRemoteCommandService` (verbose in debug, generic in release) | `error-handling-resilience` | — | LOW |
| 2.7 | Add TODO comments to Samsung and Hisense `unpairDevice` no-ops documenting the SharedPreferences pattern to follow (same as LG `clearPairing`) | `technical-debt-management` | — | LOW |
| 2.8 | Run full test suite against refactored code; verify no regressions from 2.3–2.5 | `regression-prevention` | 2.3, 2.4, 2.5 | MEDIUM |
| 2.9 ⚑ | *(Tentative)* Delete `SamsungKeyMapper.keyCodeFor` — duplicates inherited `CommandKeyMap.primaryKeyCodeFor`; update any external call sites | `code-maintenance` | — | LOW |
| 2.10 ⚑ | *(Tentative)* Fix `HisenseAdapter` fake-transport footgun — make `transportClient` required or introduce `HisenseAdapter.fake()` named constructor; update `OneRemoteApp` | `clean-code-solid` | — | MEDIUM |
| 2.11 ⚑ | *(Tentative)* Move `formatTwoDigits` from `presentation/formatting/` to a shared utils layer (e.g. `lib/src/utils/`) so `SamsungTransportFileLogger` can import it without a downward dependency | `clean-code-solid`, `abstraction-domain-modeling` | — | LOW |
| 2.12 ⚑ | *(Tentative)* Add `TvBrand.displayName` extension — replace `_brandName()` switch in `SsdpDeviceDiscoveryService` and `brand.name.toUpperCase()` at all call sites in the presentation layer | `abstraction-domain-modeling`, `clean-code-solid` | — | LOW |
| 2.13 ⚑ | *(Tentative)* Add `CommandOutcome` enum discriminator to `CommandDispatchResult` — distinguish `success`, `unsupported`, `failure`, `compatibility` so UI can branch without flag-checking | `api-design`, `clean-code-solid` | — | MEDIUM |
| 2.14 ⚑ | *(Tentative)* Extract all adapter and service wiring out of `OneRemoteApp` widget into a standalone composition root; collapse `_resolveSamsungHost`, `_resolveLgHost`, `_resolveHisenseHost` into one shared `_resolveHost` method | `clean-code-solid`, `modularity` | — | LOW |
| 2.15 ⚑ | *(Tentative)* Unify `SamsungWebSocketTransportClient._connectWithoutToken` / `_connectWithKnownToken` into one private method — removes ~60 lines of structurally identical socket/TLS-pin logic | `refactoring` | — | LOW |
| 2.16 ⚑ | *(Tentative)* Introduce `get_it` + `injectable` DI — move all service/adapter construction into `@module` classes (`LgModule`, `SamsungModule`, `HisenseModule`, `AppModule`); `OneRemoteApp` reduces to a pure widget that declares what it needs by interface; `@prod`/`@dev` env tags replace runtime `_useFakeTransports` branching | `modularity`, `clean-code-solid`, `dependency-management` | 2.14 | MEDIUM |

---

## Branch 3 — `feat/remote-selection-ui`

**Sub-goal:** Redesign Pairing Page into a Remote Selection UI — grouped scrollable list, option-3 button layout, online indicators, rename, and pairing flow fixes.

**Layout decision (option 3 with tweaks):**
- Top-right area: search/scan icon (triggers auto-scan, also fires on page load) + "Manual Setup" button
- Scrollable list with two groups:
  - Group 1: Paired TVs — swipe left to reveal Delete; tap to open that remote
  - Group 2: Available TVs (scan results) — tap to begin pairing

| ID | Task | Skills | Deps | Risk |
|----|------|--------|------|------|
| 3.1 | Add brand-specific pre-pairing confirmation prompt (shows required steps for that brand, Continue / Cancel) | `ux-constraints-awareness`, `framework-mastery` | — | MEDIUM |
| 3.2 | Add pairing status/response prompt shown after initiating pairing (progress + outcome) | `ux-constraints-awareness`, `framework-mastery` | 3.1 | MEDIUM |
| 3.3 | Rebuild page as scrollable grouped list (Group 1: paired + swipe-to-delete; Group 2: available) | `framework-mastery` | — | MEDIUM |
| 3.4 | Implement option-3 button layout: search icon (auto-scan on load) + "Manual Setup" button | `framework-mastery` | 3.3 | LOW |
| 3.5 | Add per-TV online indicator (green wifi icon = reachable; greyed = not) | `framework-mastery` | 3.3 | LOW |
| 3.6 | Add rename paired TV option (swipe-reveal or long-press) | `framework-mastery` | 3.3 | LOW |
| 3.7 | End-to-end pairing regression across LG, Samsung, Hisense | `regression-prevention` | 3.1, 3.2, 3.3 | MEDIUM |

---

## Branch 4 — `feat/tv-remote-ui`

**Sub-goal:** TV remote screen UX improvements — icon changes, pre-pairing state, brand defaults, gesture switching, and disconnection indicator.

**Disconnection detection approach (D4):**
Each transport client exposes `Stream<ConnectionState>`. LG and Samsung use WebSocket lifecycle
events (`onDone`, `onError`). Hisense uses a periodic ping. The adapter normalises all three.
The UI subscribes at the adapter level — no brand logic reaches the presentation layer.

| ID | Task | Skills | Deps | Risk |
|----|------|--------|------|------|
| 4.1 | Reposition connection icon: move beside cog, resize smaller, change to remote+wifi glyph | `framework-mastery` | — | LOW |
| 4.2 | Show "Connect a TV to begin" bubble guide when no TVs are paired, pointing to the remote-selection button | `ux-constraints-awareness`, `framework-mastery` | — | LOW |
| 4.3 | Grey out all remote buttons pre-pairing; only remote-selection button and cog remain fully active | `framework-mastery` | — | LOW |
| 4.4 | On first pairing for a TV: auto-load brand-default button grid (only show commands supported by that brand) | `framework-mastery`, `modularity` | — | MEDIUM |
| 4.5 | Implement gesture to switch between paired remotes (e.g., horizontal swipe on remote body) — confirm gesture doesn't conflict with existing scroll/button interactions | `ux-constraints-awareness`, `framework-mastery` | — | MEDIUM |
| 4.6 | Add `Stream<ConnectionState>` to transport client interface; implement for LG (WS events), Samsung (WS events), Hisense (ping poll) | `design-pattern-selection`, `abstraction-domain-modeling` | — | MEDIUM |
| 4.7 | Implement disconnection indicator in TV remote screen (consumes stream from 4.6) | `framework-mastery` | 4.6 | MEDIUM |
| 4.8 | Regression test: connection/disconnection state correctly reflects for each brand | `regression-prevention` | 4.6, 4.7 | MEDIUM |

## Branch 5 - `feat/brand-dependent-features`

**Sub-goal** Only controls available to the paired tv will be shown, unless overridden by the user.

> **Branch TBD** — tasks 5.1 and 5.2 are design/research tasks; branch name to be decided once approach is confirmed.

**Current interim approach:** `TvDevice.fromJson` derives capabilities from `brand.defaultCapabilities` only — persisted capability values are ignored on load. This assumes all devices of a brand share the same capability set, which may not hold for older models.

| ID | Task | Skills | Deps | Risk |
|----|------|--------|------|------|
| 5.1 | Design per-device capability detection: at pairing time query TV model/firmware version, map to a model-specific capability set, fall back to `brand.defaultCapabilities` if model is unrecognised. Brainstorm correct approach with Claude before implementing. | `abstraction-domain-modeling`, `api-design`, `requirement-interpretation` | — | LOW |
| 5.2 | Implement capability detection per 5.1 design; update `TvDevice.fromJson` / pairing flow to persist and restore per-device capabilities correctly | `abstraction-domain-modeling`, `framework-mastery` | 5.1 | MEDIUM |
| 5.3 | Only show remote controls supported by the paired TV's capability set; allow user override | `framework-mastery`, `ux-constraints-awareness` | 5.2 | MEDIUM |

> **Design note (5.1 — brand-variance):** Beyond capability variance, brands may change their wire
> protocol in a future firmware or OS release. When this occurs, introduce a new adapter alongside
> the existing one — never replace it, as older paired devices must remain functional.
>
> **Naming rule:** Don't add specificity until there's a second adapter to distinguish from. When
> divergence happens, name both adapters by what actually differs between them — the transport
> mechanism, protocol family, or API design (e.g. `LgSsapAdapter` + `LgRestAdapter`, or
> `SamsungTizenAdapter` + `SamsungMatterAdapter`). Only use a version number in the name if the
> version boundary IS the discriminator and no better descriptor exists. Never pre-emptively encode
> version numbers on an adapter that has no sibling yet.
>
> **Routing seam to extend:** `BrandRoutedRemoteCommandService._adapters` (`Map<TvBrand, TvBrandAdapter>`);
> the key may need to become a composite of brand + detected protocol variant. Detection should happen
> at pairing time (alongside model/firmware probing in 5.1) and be persisted per device so the correct
> adapter is selected on reconnect without re-probing.

---

## Scope Exclusions

- Samsung / Hisense `unpairDevice` full implementation deferred (no persistent pairing state yet; tracked via 2.4 TODO)
- No new brands in scope for any branch
- Grid customisation UI (beyond brand defaults in 4.4) is out of scope
