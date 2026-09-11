# Tech debt list

Findings logged while working on other tasks, not fixed as part of them — recorded per the
`clean-code-solid` skill's guidance to log an accepted/pre-existing rule deviation (MF-2) rather
than silently replicate it without comment, or silently "fix" it unilaterally mid-unrelated-task.
Each item below is independent; add new ones as their own `##` section rather than folding them
into an existing one.

---

## Bare `catch (_) {}` swallowing

**Status:** Logged, not fixed. Out of scope for the automatic-reconnection work (see
`references/device-identity-and-reconnection.md`) — this is a pre-existing, codebase-wide pattern,
not something introduced by that work.

### What

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
- `lib/remote_control/presentation/controllers/reconnection_retry_controller.dart:157` — added
  during SG1/T1.1 of the reconnection-resilience work, deliberately mirroring the existing pattern
  at the two call sites it directly composes (`BrandRoutedRemoteCommandService.connect` and
  `PairingPageData.reconcileDiscovery`), not as a fresh, independent decision.
- `lib/remote_control/data/adapters/android_tv/android_tv_cert_subject_mac_parser.dart` — added
  during SG5/T5.1. Malformed/unexpected certificate DER can throw several distinct exception types
  from the underlying ASN.1 parser with no single narrower type to catch; mirrors the same
  best-effort, must-not-crash reasoning already applied to `AndroidTvBluetoothMacTxtParser`'s mDNS
  lookup (T3.1).
- `lib/remote_control/data/adapters/android_tv/android_tv_legacy_sha256_id_migrator.dart` — added
  during SG5/T5.2. Same reasoning: a failed probe against one device (unreachable host, TLS
  handshake failure, malformed cert) must not affect migration of any other device this scan. This
  whole file is itself temporary — see the dedicated section below.

### Why it exists (steelmanning the current state)

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

### Why it's still worth fixing

A bare `catch (_)` doesn't distinguish "expected transient failure" (a socket reset, a timeout) from
"a real bug" (a `TypeError`, a `StateError`, a null-check failure introduced by a future refactor).
Today, both are silently discarded. That means a genuine defect introduced in any of these paths
could ship silently — no test failure (nothing asserts on the swallowed path), no Crashlytics
signal, no diagnostics trail. The codebase already has an in-app diagnostics sink for exactly this
gap — `AppDiagnosticsRecorder.recordUnhandledError(Object error)` — but none of the sites above
call it.

### How to fix (per-site, not a blanket change)

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

---

## Transport-level discovery services have no unit test seam

**Status:** Logged, not fixed. Surfaced while implementing `goal-automatic-reconnection-
resilience.md` SG3/T3.1 (Android TV mDNS `bt=` parsing) — not introduced by that work, and not
specific to mDNS.

### What

`MdnsDeviceDiscoveryService`, `SsdpDeviceDiscoveryService`, and `RokuSsdpDiscoveryService` each
construct their own real transport object directly inside the method body — `MDnsClient()`,
`RawDatagramSocket.bind(...)`, `RawDatagramSocket.bind(...)` respectively — rather than receiving
one via constructor injection. None of the three has a dedicated unit test file; all three would
need real network I/O (or platform channels, for mDNS's `FlutterMulticastLock`) to exercise
directly.

What the codebase *does* test, consistently, is the layer above and below this gap:

- pure parsing/inference logic extracted into its own class — `ssdp_brand_inference_test.dart` for
  SSDP, `android_tv_bluetooth_mac_txt_parser_test.dart` for mDNS's `bt` field (added alongside
  T3.1, matching this same pattern deliberately)
- the orchestration layer above all three — `composite_device_discovery_service_test.dart`,
  `discovery_result_merger_test.dart` — which only depends on the abstract `DeviceDiscoveryService`
  interface, so it's fakeable regardless of what's underneath

### Why it exists (steelmanning the current state)

This looks like a consistent, deliberate architectural choice rather than an oversight: these three
classes are thin wrappers around real OS/SDK-level socket and multicast APIs. Testing them directly
would mean either running real network I/O in CI (flaky, slow, environment-dependent) or building a
fake transport layer — neither of which the team has apparently judged worth the cost so far,
relying instead on manual validation against real devices plus the two testable seams above.

### Why it's still worth fixing (if prioritized)

Any bug introduced in the orchestration *inside* one of these three methods — a lookup ordering
mistake, a race between concurrent lookups (see mDNS's SRV/TXT concurrency in T3.1), a timeout
value applied to the wrong call — is invisible to the test suite even though the logic sitting on
either side of it (parsing, composite merging) is well covered. The gap is specifically the
"glue" that calls the SDK correctly.

### How to fix

Introduce a thin abstraction over each transport (e.g. an interface exposing just the handful of
methods each service actually calls — `start`/`lookup`/`stop` for mDNS, bind/send/listen for the
raw sockets), constructor-inject it (defaulting to the real implementation in production, same
pattern already used everywhere else in this codebase for testability), and fake it in tests. This
should be done for all three discovery services together, not just one — introducing the pattern
for mDNS alone while leaving SSDP/Roku as the odd ones out would trade one inconsistency for
another. Reasonable as its own small goal if discovery-layer correctness becomes a priority; not
scoped into any current goal.

---

## Temporary Android TV legacy `sha256`-to-`mac` id migration (SG5/T5.2) — planned removal

**Status:** Intentionally temporary, live as of 2026-09-10. **Not a bug — a scheduled removal.**

### What

`AndroidTvLegacySha256IdMigrator` (`lib/remote_control/data/adapters/android_tv/android_tv_legacy_sha256_id_migrator.dart`)
migrates a device saved under the old whole-cert-hash id scheme (`androidtv-<sha256>`, from before
the pairing certificate's subject was known to embed the device's Bluetooth MAC) onto the newer
`androidtv-<mac>` scheme, so affected users don't have to manually re-pair. Called from exactly one
place: `PairingPageData.reconcileDiscovery`.

Deliberately isolated from the permanent Android TV enrichment path
(`CompositeDeviceDiscoveryService._enrichAndroidTvIdentity`), which is completely unmodified by this
work: this migrator makes its own live connection to a discovered Android TV even when that device
already has a `bt`-derived id this scan — the permanent enrichment path skips connecting in that
case specifically to avoid a redundant probe, but this migrator needs the certificate regardless of
what id the device already has.

### Why it's temporary, not permanent

Two reasons this shouldn't stay in the codebase indefinitely:
1. **Correctness risk.** Migrating trusts `AndroidTvCertSubjectMacParser`'s MAC extraction, verified
   against only two device shapes (NVIDIA Shield, Nexus Player, both Google reference hardware). A
   third-party OEM's cert could embed something merely MAC-*shaped* without being the real MAC —
   would settle into a wrong-but-stable id for that device rather than the correct one.
2. **Diminishing returns.** The population needing migration only shrinks (every successful
   migration, and every manual re-pair, removes one device from it permanently) — this is a
   transitional shim, not something that earns its keep long-term. It also pays a real, if small,
   ongoing cost: an extra live connection per scan for every Android TV that still has a `bt`-derived
   id, purely to check a population that's expected to approach zero.

### Exit criteria — do this, don't just leave it running

Delete `android_tv_legacy_sha256_id_migrator.dart`, its test file, and its one call site (and the
`get_it`/`AndroidTvCertificateStore` imports in `pairing_page_data.dart` added only for that call,
if unused elsewhere in that file) when **either**:
- `AndroidTvLegacySha256IdMigrator.enabled` has been flipped to `false` for a full release cycle, or
- **~2026-11-10** (about two months from introduction) is reached,

whichever comes first. Do not wait for "no more reports of issues" as the trigger — the removal is
scheduled, not conditional on outcome.

---

## Adapter→transport boundary drops `TvDevice.host`, relies on registry-timing instead

**Status:** Logged, immediate symptom patched, root design gap not addressed. Found while diagnosing
a real-device pairing failure (`SocketException: Failed host lookup`) during `fix/reconnection`
testing.

### What

Every `TvBrandAdapter`/`RemoteCommandService` method (`preparePairing`, `connect`, `sendCommand`,
etc.) receives the full `TvDevice` object, host included. But `AndroidTvAdapter` hands off to its
transport client with only the bare id string:

```dart
// android_tv_adapter.dart
preparePairing → _transportClient.connect(deviceId: device.id)
```

`AndroidTvTcpTransportClient` then has to re-derive a host it was never given, via an injected
resolver function (`String Function(String deviceId) _hostResolver`, wired in
`remote_control_di_config.dart`): try `DeviceIdentityRegistry.hostForStableId(deviceId)` first, then
fall back to regex-extracting an IPv4 substring from the id itself
(`legacy_host_resolver.dart`). This is a deliberate, existing pattern (see the goal doc's D-7) used
identically across every brand's transport client, not something introduced by this branch.

### The bug it caused

T3.1 started giving unpaired Android TVs a `androidtv-<mac>` id (instead of always
`androidtv-<ip>`). For a device that has never been paired before, `DeviceIdentityRegistry` has no
entry yet, and the regex fallback finds no IP inside a MAC string — both resolution paths return
empty, so `SecureSocket.connect('', ...)` fails with "Failed host lookup." The registry-based
resolver mechanism was only ever safe by accident, because every discovery-time id used to be
IP-derived; T3.1 broke that unstated assumption without anyone noticing until real-device testing.

### Immediate fix applied (kept for now, not the root fix)

`lib/remote_control/data/brand_routed_remote_command_service.dart`, in `preparePairing` — added a
call to `_registerIdentity(device)` **before** `await adapter.preparePairing(device: device)` (was
previously only called once, on `enriched`, after pairing already completed). This doesn't change
*what* gets registered or *how* it's looked up — same registry, same `_hostResolver` mechanism — it
only changes *when* the existing registration happens, so the entry exists before the same lookup
that was failing. Commit `b1f90a5`; regression test in
`test/lib/remote_control/data/brand_routed_remote_command_service_test.dart`
(`_RegistryCheckingAdapter`).

### The proper fix, not yet built

Change transport-client methods that are always called with a full `TvDevice` in hand
(`connect`, `preparePairing`) to receive the host directly, rather than re-deriving it through a
timing-dependent lookup:

```dart
// instead of:
Future<void> connect({required String deviceId})
// this:
Future<void> connect({required String deviceId, required String host})
```

`_hostResolver`/`DeviceIdentityRegistry` would stay in place for the calls that genuinely only ever
have a bare id (`cancelPairing(deviceId)`, secret-store lookups mid-handshake — continuations of a
handshake started earlier, with no live `TvDevice` in scope at that point) — this isn't a proposal to
delete the registry, only to stop relying on it for the initial call, where relying on it was never
actually necessary.

**Open question, not decided:** pass `host` as an added parameter (matches this class's existing
narrow-parameter style; ISP — a transport client has no legitimate use for `displayName`,
`capabilities`, etc.), or pass the whole `TvDevice` (avoids primitive obsession / possible
id-vs-host mismatch between two separate params; more future-proof if another field is ever needed).
Both are legitimate; leaning toward `host`-as-parameter for consistency with the existing convention
at this exact boundary, but not committed.

### Why it's still worth fixing properly

The immediate fix only closes the one gap that was actually hit (first-time pairing). The underlying
fragility — any transport-client call site relying on `_hostResolver` succeeding, for an id format
the registry hasn't been populated for yet — is a class of bug, not a single instance. It's currently
only known to be safe because every code path that could hit it happens to register in time; a
future change to id-assignment timing (in Android TV or any other brand) could silently reintroduce
this exact failure mode elsewhere.

### Scope if fixed

Would touch every brand's transport client's `connect`/`preparePairing` signature (Samsung, LG,
Hisense, Sony, Roku, Android TV), not just Android TV's — a breaking change to an internal interface,
requiring explicit confirmation before starting (`api-design` skill: "Request confirmation for
breaking changes"), not something to fold into an unrelated bug fix.
