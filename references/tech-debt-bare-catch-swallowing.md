# Tech debt: bare `catch (_) {}` swallowing

**Status:** Logged, not fixed. Out of scope for `goal-automatic-reconnection-resilience.md` — this
is a pre-existing, codebase-wide pattern, not something introduced by that work. Recorded here per
the `clean-code-solid` skill's guidance to log an accepted/pre-existing rule deviation (MF-2) rather
than silently replicate it without comment or silently "fix" it unilaterally mid-unrelated-task.

## What

`language-specific-implementation.md` explicitly prohibits "swallowing bare `Exception`/`Throwable`."
This codebase does it pervasively — 50+ sites at last count (`grep -rn "catch (_)" lib/`). A few
examples, deliberately not the whole list (it changes as the code does; re-run the grep for the
current count):

- `lib/remote_control/data/brand_routed_remote_command_service.dart:50` (`connect()`) and `:273`
- `lib/remote_control/presentation/pages/pairing_page_data.dart:83,106,121` (`reconcileDiscovery`)
- `lib/remote_control/presentation/pages/pairing_page.dart` (8 sites)
- `lib/remote_control/data/adapters/**/*.dart` — most brand adapters and transport clients (LG,
  Samsung, Hisense, Sony, Android TV) have at least one
- `lib/app/monetization/pro_entitlement_service.dart:79,130,180`
- `lib/remote_control/presentation/controllers/reconnection_retry_controller.dart:157` — the newest
  instance, added during SG1/T1.1 of the reconnection-resilience work. Added deliberately to mirror
  the existing pattern at the two call sites it directly composes
  (`BrandRoutedRemoteCommandService.connect` and `PairingPageData.reconcileDiscovery`), not as a
  fresh, independent decision — flagged here per the user's request rather than left unremarked.

## Why it exists (steelmanning the current state)

Most of these sites are deliberately "best-effort" operations — a background reconnect attempt, a
discovery/reconcile pass, a non-critical persistence write — where the surrounding code already
treats failure as an expected, recoverable outcome (e.g. connection state / a returned bool already
carries the real signal) and doesn't want a transient LAN hiccup to propagate into the UI or crash
reporting. The codebase has a real, working mechanism for the "genuinely unexpected" tier of error:
a global zone handler (`lib/app/diagnostics/unhandled_zone_error.dart`) forwards uncaught errors to
Crashlytics, filtering out expected transport noise (`SocketException`) via `UnhandledZoneError.isFatal`.
The comment on `BrandRoutedRemoteCommandService.connect()` ("unhandled errors here are reported as
Crashlytics crashes") gestures at this pipeline — but a bare `catch (_) {}` around the awaited call
means nothing from *that specific call* ever reaches it; the comment is more aspirational than
accurate for errors thrown synchronously inside the awaited call itself.

## Why it's still worth fixing

A bare `catch (_)` doesn't distinguish "expected transient failure" (a socket reset, a timeout) from
"a real bug" (a `TypeError`, a `StateError`, a null-check failure introduced by a future refactor).
Today, both are silently discarded. That means a genuine defect introduced in any of these paths
could ship silently — no test failure (nothing asserts on the swallowed path), no Crashlytics
signal, no diagnostics trail. The codebase already has an in-app diagnostics sink for exactly this
gap — `AppDiagnosticsRecorder.recordUnhandledError(Object error)` — but none of the sites above
call it.

## How to fix (per-site, not a blanket change)

This isn't safe to fix with a single mechanical pass — each site needs a judgment call:

1. **Narrow the catch to the actually-expected exception type** where the failure mode is known
   (e.g. `on SocketException`, `on TimeoutException`) so anything else propagates to the zone
   handler → Crashlytics (filtered by `UnhandledZoneError.isFatal`) instead of being silently
   discarded.
2. **Where "truly any failure is fine to ignore" is a deliberate design choice** (e.g. a
   best-effort persistence write that a later pass will retry), keep the broad catch but route the
   caught error through `AppDiagnosticsRecorder.recordUnhandledError(error)` (already
   GetIt-registered as a singleton) so it's visible in the copyable diagnostics report even though
   it doesn't interrupt the user.
3. Audit sites individually — some may already be correct as-is (e.g. genuinely expecting a wide
   range of platform-specific exceptions with no actionable distinction available). Don't treat
   "convert every bare catch" as the goal; treat "no swallowed exception is invisible to
   troubleshooting" as the goal.

No task tracking this exists yet in any goal file — if this gets prioritized, it should become its
own goal document rather than folding into an unrelated one, given the scope (~15+ files).
