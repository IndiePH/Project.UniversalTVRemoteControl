# Goal: Localization

**Goal ID:** `localization`
**Created:** 2026-04-28
**Branch:** `feat/localization`
**Status:** `in-progress`
**Owner:** wlvyr

---

## Goal Statement

Replace every hardcoded user-facing string in the application with locale-aware equivalents.
The English strings that exist today become the base locale; the infrastructure introduced here
makes adding further locales a single `.arb` file with no code changes.

---

## Decisions Log

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Use `flutter_localizations` + `intl` + ARB files as the localization toolchain | Flutter-official; codegen enforces type safety on every string key; parameterized strings become typed method parameters |
| D2 | Parameterized strings use ARB `{placeholder}` syntax → codegen produces a named Dart parameter; e.g. `"pairingNoAdapter": "No adapter configured for {brandName}."` becomes `String pairingNoAdapter(String brandName)` | No manual string interpolation; type-checked at compile time |
| D3 | Define a flat `LocalizedStrings` abstract interface (application layer) with name-prefix grouping (e.g. `pairing*`, `remote*`); backed by `AppLocalizedStrings` concrete (app layer) that wraps the generated `AppLocalizations` via `static late AppLocalizations _l10n` updated from `MaterialApp.builder` | ~30–50 strings total — nested classes would require four maintenance locations per string (ARB, generated class, nested interface, nested concrete) with no organisation gain a flat prefix-grouped interface doesn't already provide; `AppLocalizedStrings` keeps `_l10n` as an implementation detail invisible to callers |
| D4 | Services and registries receive `LocalizedStrings` via constructor injection (`required LocalizedStrings localizedStrings`); DI config constructs them with `sl<LocalizedStrings>()`; no static accessor on the interface | Constructor injection is consistent with how all other dependencies (`VariantResolutionRegistry`, adapters) are wired; static accessor on the interface was replaced because DI already fulfils that role |
| D5 | `AppLocalizedStrings` registered as `sl.registerSingleton<LocalizedStrings>(AppLocalizedStrings())`; `MaterialApp.builder` calls `AppLocalizedStrings.update(AppLocalizations.of(context)!)` on every rebuild, keeping the singleton current across locale changes without re-registration | Singleton identity is stable so DI-injected references never go stale; `MaterialApp.builder` fires on every locale change so the static `_l10n` is always current |
| D6 | Runtime locale switching supported without restart — `MaterialApp.locale` driven by a `ValueNotifier<Locale>` registered in DI; widgets re-translate automatically via `AppLocalizations.of(context)`; services pick up the new locale on next call via the updated singleton | Locale `ValueNotifier` in DI is consistent with the existing DI pattern and lays groundwork for a future settings cog; to change locale the settings screen mutates `sl<ValueNotifier<Locale>>().value` — no restart required; **NOTE:** `restart()` re-registers the notifier from `PlatformDispatcher.instance.locale`, so a persisted user preference must be loaded from SharedPreferences in `DiBootstrap` when that feature is built |
| D7 | String arrays (e.g. `PrePairingStepsRegistry` steps) handled via numbered ARB keys per brand (`pairingLgPreStep0`, `pairingLgPreStep1`, …); registry reads them by iterating a step count constant | ARB has no native array type; numbered keys keep codegen clean and fully type-safe |
| D8 | `CommandDispatchResult.message` strings in `BrandRoutedRemoteCommandService` are in scope for localization — confirmed user-facing via `MessageHandler.sanitize` → `pairing_page_coordinator` and `remote_home_page` | These strings reach the user's screen; they must be translated |
| D9 | English is the only locale delivered in this branch; the infrastructure makes adding further locales a single `.arb` file | Scope control — no second locale until the base infrastructure is stable |
| D10 | Debug/dev-only strings (DragDrop debug labels, transport log labels, `lib/remote_control/debug/`) excluded from localization scope | Never shown to end users; translating them adds noise with no user value |
| D11 | `TextInputCompatibilityException` carries a `TextCompatibilityError` enum instead of a pre-formatted string; `BrandRoutedRemoteCommandService.sendText` resolves the enum to a localized string at the catch site | Keeps localization resolution at the service boundary; adapter layer stays string-free; eliminates dynamic `appContext` diagnostic suffix from Samsung throw site (not user-meaningful) |

---

## Sub-goal 1 — Architecture & Infrastructure Setup ✓ DONE

| ID | Task | Skills | Deps | Risk |
|----|------|--------|------|------|
| 1.1 | Add `flutter_localizations` + `intl` to `pubspec.yaml`; add `flutter: generate: true`; create `lib/l10n/` and a minimal `lib/l10n/app_en.arb`; create `l10n.yaml`; run `flutter gen-l10n` and confirm `AppLocalizations` is generated | `framework-mastery`, `language-specific-implementation` | — | LOW |
| 1.2 | Wire `AppLocalizations` into `MaterialApp`: add `localizationsDelegates`, `supportedLocales`; confirm `AppLocalizations.of(context)` resolves in a widget | `framework-mastery` | 1.1 | LOW |
| 1.3 | Define flat `LocalizedStrings` abstract interface in `lib/app/` — one typed method per user-facing string, name-prefixed by domain group (`pairing*`, `remote*`); parameterized strings are methods, static strings are getters, step arrays return `List<String>` | `abstraction-domain-modeling`, `api-design`, `clean-code-solid` | 1.1 | MEDIUM |
| 1.4 | Implement `AppLocalizedStrings` in `lib/app/`: holds `static late AppLocalizations _l10n`; exposes `static void update(AppLocalizations l10n)`; implements every `LocalizedStrings` method by delegating to `_l10n`; register as `sl.registerSingleton<LocalizedStrings>(AppLocalizedStrings())` in DI config; call `AppLocalizedStrings.update(AppLocalizations.of(context)!)` inside `MaterialApp.builder` | `framework-mastery`, `modularity` | 1.2, 1.3 | MEDIUM |
| 1.5 | Add a `ValueNotifier<Locale>` locale provider registered in DI; wire it so `MaterialApp.locale` reacts to changes — enables programmatic locale switching from a settings UI in a future branch | `framework-mastery`, `dependency-management` | 1.4 | LOW |

---

## Sub-goal 2 — Service & Data Layer String Extraction ✓ DONE

| ID | Task | Skills | Deps | Risk | Status |
|----|------|--------|------|------|--------|
| 2.1 | Audit all string literals in `lib/remote_control/data/` and `lib/remote_control/application/` that surface to users via `CommandDispatchResult.message` / `MessageHandler.sanitize`; list every string and its runtime parameters | `technical-debt-management`, `abstraction-domain-modeling` | — | LOW | ✓ done |
| 2.2 | Add all `BrandRoutedRemoteCommandService` user-facing messages to `app_en.arb` and `LocalizedStrings`; add `required LocalizedStrings localizedStrings` constructor parameter; replace hardcoded literals with `_localizedStrings.pairingXxx(params)` / `_localizedStrings.remoteXxx(params)` calls; update DI config to inject `sl<LocalizedStrings>()` | `language-specific-implementation`, `framework-mastery` | 1.3, 1.4, 2.1 | MEDIUM | ✓ done |
| 2.3 | Localize `DefaultPairingProgressHintRegistry` hints — add hint strings to ARB and `LocalizedStrings`; add `required LocalizedStrings localizedStrings` constructor parameter; replace static `_hints` map with a lookup against `_localizedStrings`; update DI config | `framework-mastery`, `abstraction-domain-modeling` | 1.3, 1.4, 2.1 | MEDIUM | ✓ done |
| 2.4 | Localize `DefaultPrePairingStepsRegistry` steps — add numbered ARB keys per brand (`pairingLgPreStep0`, …) and corresponding `LocalizedStrings` methods; add `required LocalizedStrings localizedStrings` constructor parameter; replace static `_steps` map with a builder iterating step-count constants; update DI config | `framework-mastery`, `abstraction-domain-modeling` | 1.3, 1.4, 2.1 | MEDIUM | ✓ done |

---

## Sub-goal 3 — Presentation Layer String Extraction

| ID | Task | Skills | Deps | Risk |
|----|------|--------|------|------|
| 3.1 | Audit all hardcoded string literals in `lib/remote_control/presentation/` and `lib/app/`; catalogue every string, its widget context, and whether it contains runtime values | `technical-debt-management` | — | LOW |
| 3.2 | Add all presentation strings to `app_en.arb`; replace every `Text('…')`, `tooltip:`, `title:`, `label:`, `hintText:` literal with `AppLocalizations.of(context)!.key` (use a local `final l10n = AppLocalizations.of(context)!` alias where multiple keys are used in one build method) | `framework-mastery`, `language-specific-implementation` | 1.2, 3.1 | MEDIUM |
| 3.3 | Localize remaining `lib/app/` and `lib/main.dart` user-facing strings (app title, etc.) | `framework-mastery` | 1.2, 3.1 | LOW |

---

## Sub-goal 4 — Validation

| ID | Task | Skills | Deps | Risk |
|----|------|--------|------|------|
| 4.1 | Update unit tests for `BrandRoutedRemoteCommandService` and both registries: (a) add `FakeLocalizedStrings` (plain Dart class implementing `LocalizedStrings`) and pass it via constructor in `setUp` — no Flutter or `AppLocalizations` machinery needed; (b) update any string assertions that currently hardcode English literals to assert against the fake's known return values instead, so tests remain meaningful without coupling to real translation content | `test-creation-strategy`, `regression-prevention` | 2.2, 2.3, 2.4 | MEDIUM |
| 4.2 | Run full test suite; fix any regressions introduced by string extraction | `regression-prevention` | 4.1, 3.2 | MEDIUM |
| 4.3 | Visual smoke test across all screens: confirm all UI strings display correct English text; no ARB key names or `null` bleed-through visible | `framework-mastery`, `regression-prevention` | 3.2, 4.1 | LOW |

---

## Scope Exclusions

- No second locale (e.g. Spanish) in this branch — infrastructure makes it a single `.arb` file addition later
- No RTL layout changes
- Debug/dev-only strings (`DragDrop Debug`, transport log labels, `lib/remote_control/debug/`) not extracted
- Settings cog (language selector) deferred — a future branch will add a settings page where the user can override the default device locale; the DI-registered `ValueNotifier<Locale>` is already wired to propagate the change app-wide without a restart; persisted preference must survive restarts via SharedPreferences loaded in `DiBootstrap`
- No nested classes inside `LocalizedStrings` — flat interface with name prefixes is sufficient at current string volume
