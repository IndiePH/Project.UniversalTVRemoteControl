# Refactor Proposal

Derived from a full `lib/` review against the current product spec and implementation plan.
Items are ordered: high-priority (safe, isolated) first, then medium-priority (structural).

---

## Status Key

| Symbol | Meaning |
|---|---|
| ✅ | Resolved in a recent push |
| 🔶 | Partially addressed — work remains |
| ❌ | Still open |
| 🆕 | New finding from latest review |

---

## Summary Table

| # | File(s) | Issue | Type | Risk | Status |
|---|---|---|---|---|---|
| R-01 | `SsdpDeviceDiscoveryService`, `PairingPage` | `_capabilitiesForBrand` duplicated | DRY violation | Low | ✅ |
| R-02 | `PairingPage`, `RemoteHomePage` | `_twoDigits` / timestamp formatting duplicated | DRY violation | Low | ✅ |
| R-03 | `SamsungKeyMapper` | `keyCodeFor` duplicates inherited `primaryKeyCodeFor` | Dead method | Low | ❌ |
| R-04 | `RemoteHomePage._actionForItem` | Five unreachable switch cases | Dead code | Low | ✅ |
| R-05 | `RemoteHomePage` | `firstOrNull` extension shadows Dart 3 built-in | Redundant extension | Low | ✅ |
| R-06 | `HisenseAdapter` | `sendText` logs instead of throwing `UnsupportedError` | Inconsistency / latent bug | Low | ✅ |
| R-07 | `OneRemoteApp` | `InMemoryDeviceRepository` used in production | Missing persistence | Medium | ✅ |
| R-08 | `layout_repository.dart` | `LayoutPosition` model in the application layer | Layer placement | Medium | ✅ |
| R-09 | `TvBrand`, `SsdpDeviceDiscoveryService`, `PairingPage` | No `displayName` getter — brand naming scattered | Scattered display logic | Medium | ❌ |
| R-10 | `SamsungAdapter` | Default constructor silently uses fake transport | Surprising default | Medium | ✅ |
| R-11 | `CommandDispatchResult` | No discriminated type for `unsupported` vs `failure` | Design gap | Medium | 🔶 |
| N-01 | `HisenseAdapter` | Default constructor silently uses fake transport | Surprising default | Medium | 🆕 ❌ |
| N-02 | `SamsungTransportFileLogger` | Private `_twoDigits` duplicates `formatTwoDigits` — unreachable across layers | DRY / layer placement | Low | 🆕 ❌ |
| N-03 | `LgWebSocketTransportClient` | `sendKey()` growing if/else dispatch chain | Design smell | Medium | 🆕 ❌ |
| N-04 | `LgWebSocketTransportClient` | `_muteStates`/`_powerStates`/`_playingStates` duplicate toggle boilerplate | DRY violation | Medium | 🆕 ❌ |
| N-05 | `BrandRoutedRemoteCommandService` | 4 catch blocks expose raw `$error` to users | Error handling | Low | 🆕 ❌ |
| N-06 | `SamsungAdapter`, `HisenseAdapter` | `unpairDevice` no-ops undocumented | Doc debt | Low | 🆕 ❌ |
| N-07 | `OneRemoteApp`, host resolvers | Widget doubles as composition root; three identical host resolver methods | SRP / DRY | Medium | 🆕 ❌ |
| N-08 | `SamsungWebSocketTransportClient` | `_connectWithoutToken` / `_connectWithKnownToken` structurally identical (~60 lines each) | DRY | Low | 🆕 ❌ |
| N-09 | `OneRemoteApp`, all adapters | No DI container — construction logic entangled with the widget layer | Architecture | Medium | 🆕 ❌ |
| N-10 | `LgWebSocketTransportClient`, `SamsungWebSocketTransportClient` | `_openSocket(Uri)` duplicated — difference is intentional (accept-all vs trust-store); deferred to 4.6 | Informational | Low | 🆕 ❌ |
| N-11 | `TransportClient` | Empty marker interface with no contract and no polymorphic consumers; deferred to 4.6 | Informational | Low | 🆕 ❌ |

---

## Skills Used for Analysis

| Skill | Domain | What it informed |
|---|---|---|
| `refactoring` | 1-core-engineering | Primary driver — scanned for structural improvements, DRY violations, dead code, and inconsistencies without behavior change |
| `clean-code-solid` | 1-core-engineering | DRY violations: ✅ R-01 (capabilities), ✅ R-02 (formatter), 🆕 N-02 (formatter layer gap); ✅ R-08 layer placement; ✅ R-06 adapter inconsistency |
| `abstraction-domain-modeling` | 1-core-engineering | Layer placement: ✅ R-08 (`LayoutPosition`); brand ownership: ❌ R-09 (`TvBrand.displayName`), ✅ R-01 (`TvBrand.defaultCapabilities`); 🆕 N-02 (shared util layer) |
| `code-maintenance` | 1-core-engineering | Dead code: ❌ R-03 (`keyCodeFor`); ✅ R-04 (switch cases); ✅ R-05 (`firstOrNull`) |
| `technical-debt-management` | 2-architecture-system-design | Structural gaps: ✅ R-07 (persistence added), ✅ R-10 + 🆕 N-01 (fake transport defaults — Samsung fixed, Hisense open), 🔶 R-11 (discriminated result type) |

---

## Resolved Items

### R-01 · `_capabilitiesForBrand` duplication — ✅ Resolved

`TvBrandCapabilities` extension with `defaultCapabilities` getter added in
`domain/models/tv_brand_capabilities.dart`. `SsdpDeviceDiscoveryService` and
`PairingPageData.buildManualDevice` both delegate to `brand.defaultCapabilities`.

---

### R-02 · `_twoDigits` / timestamp formatting duplication — ✅ Resolved (presentation layer)

`formatTwoDigits` extracted to `presentation/formatting/two_digit_format.dart`.
Both `pairing_page_data.dart` and `remote_home_page.dart` now import and use it.

> **Residual (N-02):** `SamsungTransportFileLogger` (data layer) still has a private
> `_twoDigits` because it cannot import from `presentation/formatting/`. See N-02.

---

### R-04 · Dead entries in `_actionForItem` switch — ✅ Resolved

Entire `_actionForItem` switch replaced. `RemoteHomeRemoteGrid` now uses a
`_commandByItemId` constant map for simple icon buttons, and named builder methods
(`_buildDpadItem`, `_buildPlayPauseItem`, etc.) for composite controls. No dead cases remain.

---

### R-05 · Redundant `firstOrNull` extension — ✅ Resolved

Extension deleted. Dart 3 built-in `Iterable.firstOrNull` is used directly.

---

### R-06 · `HisenseAdapter.sendText` silently logs instead of throwing — ✅ Resolved

`sendText` now throws `UnsupportedError(...)`, consistent with `LgAdapter`.

---

### R-07 · `InMemoryDeviceRepository` used in production — ✅ Resolved

`SharedPrefsDeviceRepository` implemented and wired in `one_remote_app.dart:39`.
Devices now survive app restarts. Mirrors the existing `SharedPrefsLayoutRepository` pattern.

---

### R-10 · `SamsungAdapter` defaults to fake transport — ✅ Resolved

`transportClient` is now a `required` named parameter in `SamsungAdapter` (`samsung_adapter.dart:16`).
Zero-arg construction no longer compiles; all callers must be explicit about the transport.
`OneRemoteApp._buildSamsungAdapter()` passes either `FakeSamsungTransportClient` or
`SamsungWebSocketTransportClient` explicitly. N-01 (`HisenseAdapter`) remains open.

---

### R-08 · `LayoutPosition` misplaced in the application layer — ✅ Resolved

`LayoutPosition` moved to `domain/models/layout_position.dart`.

---

## Open — High Priority (Safe, No Behavior Change)

### R-03 · `SamsungKeyMapper.keyCodeFor` duplicates inherited `primaryKeyCodeFor`

**File:** `data/adapters/samsung/samsung_key_mapper.dart:32`

```dart
String? keyCodeFor(RemoteCommand command) {
  final keyCodes = keyCodesFor(command);
  return keyCodes.isEmpty ? null : keyCodes.first;
}
```

`CommandKeyMap.primaryKeyCodeFor` (in `command_key_map.dart:9`) is byte-for-byte identical.
No internal call site in the file uses the distinct name.

**Proposed fix:** Delete `keyCodeFor`. Update any external call sites to use `primaryKeyCodeFor`.

---

### N-02 · `formatTwoDigits` not accessible from the data layer

**File:** `data/adapters/samsung/samsung_transport_file_logger.dart:93`

```dart
String _twoDigits(int value) => value.toString().padLeft(2, '0');
```

`formatTwoDigits` lives in `presentation/formatting/two_digit_format.dart`, which the data
layer cannot import without creating an illegal downward dependency. Both implementations
are identical.

**Proposed fix:** Move `formatTwoDigits` to `src/utils/date_format.dart` (or a similar
shared-utils location outside the feature layers). Update all three call sites
(`pairing_page_data.dart`, `remote_home_page.dart`, `samsung_transport_file_logger.dart`).

---

## Open — Medium Priority (Structural)

### R-09 · `TvBrand` has no `displayName`

**Files:**
- `data/ssdp_device_discovery_service.dart:159` — private `_brandName()` switch
- `presentation/pages/pairing_page_data.dart:52` — `brand.name.toUpperCase()`
- `presentation/widgets/pairing_page_sections.dart:112,170,171,267` — `brand.name.toUpperCase()`

Brand display names are produced two different ways across three files. Adding a new brand
requires finding and updating all sites.

**Proposed fix:** Add a `displayName` getter (or extension) to `TvBrand`:

```dart
extension TvBrandDisplay on TvBrand {
  String get displayName => switch (this) {
    TvBrand.samsung => 'Samsung',
    TvBrand.lg      => 'LG',
    TvBrand.hisense => 'Hisense',
  };
}
```

Replace `_brandName(brand)` and `brand.name.toUpperCase()` at all four sites.
Can land in the same commit as N-02 since both touch `tv_brand.dart` adjacently.

---

### N-01 · `HisenseAdapter` defaults to fake transport

**File:** `data/adapters/hisense_adapter.dart:14`

```dart
HisenseAdapter({
  HisenseTransportClient? transportClient,
  ...
}) : _transportClient = transportClient ?? FakeHisenseTransportClient(),
```

`SamsungAdapter` was fixed (R-10 ✅ — `transportClient` is now `required`). `HisenseAdapter`
still silently falls back to the no-op fake when called with no argument.
`OneRemoteApp._buildHisenseAdapter()` still relies on this zero-arg path for fake mode.

**Proposed fix:** Make `transportClient` required, or introduce a named `HisenseAdapter.fake()`
constructor. Update `OneRemoteApp` to call the explicit factory.

---

### R-11 · `CommandDispatchResult` has no discriminated outcome type — 🔶 Partial

**File:** `application/command_dispatch_result.dart`

Partial progress: `isCompatibilityIssue` flag was added and a fourth `compatibility()`
constructor distinguishes IME/text compatibility failures. However, `.unsupported(message)`
and `.failure(message)` still both produce `isSuccess: false, isCompatibilityIssue: false`
with no programmatic distinction. The UI cannot tell "this command is simply unavailable on
this TV" from "something went wrong sending it".

**Proposed fix:** Add an outcome discriminator:

```dart
enum CommandOutcome { success, unsupported, failure, compatibility }
```

Add `final CommandOutcome outcome` to `CommandDispatchResult`. Update the four named
constructors to assign matching outcomes. Update UI call sites to branch on `outcome`
(e.g., silently ignore `unsupported` vs. toast on `failure`).

---

---

### N-03 · `LgWebSocketTransportClient.sendKey()` — growing if/else dispatch chain

**File:** `data/adapters/lg/lg_websocket_transport_client.dart:185–221`

```dart
if (keyCode.startsWith(lgPointerPrefix)) { … }
else if (keyCode.startsWith(lgLaunchPrefix)) { … }
else if (keyCode == 'ssap://audio/setMute') { … }
else if (keyCode == lgPowerToggleKey) { … }
else if (keyCode == lgPlayPauseToggleKey) { … }
else { … }
```

Five branches today; every new stateful command adds another. State and dispatch logic are
scattered across the method rather than co-located per command.

**Proposed fix:** Introduce a `Map<String, _LgCommandHandler>` (or closure map) where each
entry owns both the dispatch logic and any per-device state it needs. Best addressed alongside N-04.

---

### N-04 · `_muteStates`, `_powerStates`, `_playingStates` — duplicate toggle boilerplate

**File:** `data/adapters/lg/lg_websocket_transport_client.dart:72–80` (fields) + `sendKey()` branches

```dart
final Map<String, bool> _muteStates = {};
final Map<String, bool> _powerStates = {};
final Map<String, bool> _playingStates = {};
```

Three separate maps with identical toggle pattern `!(states[deviceId] ?? defaultValue)`.
Adding any new stateful command duplicates the field, the toggle, and the `_resetConnection`
cleanup.

**Proposed fix:** Unify into a generic abstraction (e.g. a `_ToggleState` wrapper or a
single `Map<String, Map<String, bool>>` keyed by command key). Address together with N-03.

---

### N-05 · `BrandRoutedRemoteCommandService` — raw `$error` in 4 catch blocks

**File:** `data/brand_routed_remote_command_service.dart:40, 69, 94, 123`

```dart
return CommandDispatchResult.failure('Failed to pair ${device.displayName}: $error');
```

All four generic `catch` blocks interpolate `$error` directly. In release builds this may
expose raw stack traces or internal exception text through the UI.

**Proposed fix:** Guard with `kDebugMode` (from `flutter/foundation.dart`): show `$error`
detail in debug, `'Something went wrong.'` in release. Applies to `preparePairing`,
`submitPairingCode`, `sendCommand`, and `sendText`.

---

### N-06 · `SamsungAdapter` and `HisenseAdapter` `unpairDevice` no-ops undocumented

**Files:** `data/adapters/samsung_adapter.dart:35`, `data/adapters/hisense_adapter.dart:31`

```dart
@override
Future<void> unpairDevice({required TvDevice device}) async {}
```

Empty body with no explanation. Anyone adding persistent pairing state for either brand
will have no indication that `unpairDevice` must be updated to clear it.

**Proposed fix:** Add a TODO comment referencing the SharedPreferences pattern established
by LG's `clearPairing` / `LgPairingKeyStore`.

---

### N-07 · `OneRemoteApp` widget doubles as composition root

**Files:** `lib/app/one_remote_app.dart:94–147`

`_buildSamsungAdapter()`, `_buildLgAdapter()`, `_buildHisenseAdapter()` sit inside a
`StatefulWidget`. The widget has direct knowledge of concrete transport clients, key stores,
and the fake/real branching flag. Adding a new brand or changing a transport means modifying
the widget. Three host resolver methods (`_resolveSamsungHost`, `_resolveLgHost`,
`_resolveHisenseHost`, lines 127–147) are byte-for-byte identical — the brand name plays no
role in the logic.

**Proposed fix:** Extract wiring into a standalone composition root (superseded by N-09 if
the DI container is adopted). Collapse the three resolver methods into one shared
`_resolveHost(String deviceId)`.

---

### N-08 · `SamsungWebSocketTransportClient._connectWithoutToken` / `_connectWithKnownToken`

**File:** `lib/remote_control/data/adapters/samsung/samsung_websocket_transport_client.dart:302–366`

Both methods share ~60 lines of identical logic: build URI, open socket via `_openSocket`,
bind with `_bindSocket`, await handshake completer, commit or abandon TLS pins on
success/error. They differ only in whether `&token=…` is appended to the URI.

**Proposed fix:** Unify into `_connectWith({String? token})` — token absent = no-token path,
token present = known-token path. Removes ~55 lines of duplication.

---

### N-09 · No DI container — construction entangled with the app widget

**File:** `lib/app/one_remote_app.dart`

The application has no DI layer. All service construction lives in `OneRemoteApp._build*`
methods, making it impossible to swap implementations without modifying the widget, and
impossible to add a new brand without touching the app shell.

**Proposed fix:** Introduce `get_it` (no `injectable`) with an `IDiConfig`/`DiBootstrap`
pattern — a direct Dart analog of the Wlvyr.Common `IDIConfig<Container,AppSettings>` +
`DIBootstrap.Initialize()` approach. No annotations on actual service/adapter classes.

`injectable` was evaluated and rejected — its annotation-on-actual-class mechanism conflicts
with the requirement to keep domain/data classes annotation-free.

**How it maps to the C# SimpleInjector / Wlvyr.Common pattern:**

| C# | Dart/Flutter |
|---|---|
| `SimpleInjector.Container` | `GetIt.instance` |
| `IDIConfig<Container, AppSettings>` | `IDiConfig` interface (`configure(GetIt, AppEnvironment)`) |
| `DIBootstrap.Initialize()` | `DiBootstrap.initialize(AppEnvironment)` — iterates `_configs` list |
| `container.Register<IFoo, Foo>()` | `sl.registerSingleton<IFoo>(Foo(...))` inside `configure()` |
| Assembly scanning via reflection | Manual list in `DiBootstrap._configs` (Dart has no runtime reflection) |
| `container.Verify()` | `GetIt.instance.allReady()` (async readiness check) |
| `AppEnvironment.Production` | `AppEnvironment.production` enum value passed to `configure()` |

The only structural difference from C#: Dart cannot auto-discover `IDiConfig` implementations
at runtime, so they are manually listed in `DiBootstrap._configs`. Adding a new feature module
means adding one line there — the same single-file change-point as registering a new
`IDIConfig` in C#.

**What the code looks like:**

```dart
// lib/app/configurations/app_environment.dart
enum AppEnvironment { production, development, debug }

// lib/app/configurations/i_di_config.dart
abstract interface class IDiConfig {
  void configure(GetIt sl, AppEnvironment env);
}

// lib/remote_control/configurations/di_remote_control.dart
class DiRemoteControl implements IDiConfig {
  @override
  void configure(GetIt sl, AppEnvironment env) {
    switch (env) {
      case AppEnvironment.production:
        sl.registerSingleton<LgTransportClient>(
          LgWebSocketTransportClient(hostResolver: _resolveHost, keyStore: LgPairingKeyStore()),
        );
        // Samsung, Hisense production instances…
      case AppEnvironment.development || AppEnvironment.debug:
        sl.registerSingleton<LgTransportClient>(FakeLgTransportClient());
        // Samsung, Hisense fake instances…
    }
    // Adapters and services are environment-agnostic — registered once.
    sl.registerSingleton<TvBrandAdapter>(LgAdapter(transportClient: sl<LgTransportClient>()));
    sl.registerSingleton<RemoteCommandService>(BrandRoutedRemoteCommandService(...));
  }
}

// lib/app/configurations/di_bootstrap.dart
class DiBootstrap {
  static final _configs = <IDiConfig>[
    DiRemoteControl(),
    // DiTheme(), DiApp(), … — one line per feature module
  ];

  static void initialize(AppEnvironment env) {
    for (final config in _configs) {
      config.configure(GetIt.instance, env);
    }
  }
}

// lib/main.dart  ← only file that changes to switch environments
void main() {
  DiBootstrap.initialize(AppEnvironment.production);
  runApp(const OneRemoteApp());
}

// lib/app/one_remote_app.dart  ← pure widget, no wiring
class OneRemoteApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RemoteHomePage(
        commandService: GetIt.instance<RemoteCommandService>(),
        discoveryService: GetIt.instance<DeviceDiscoveryService>(),
        deviceRepository: GetIt.instance<DeviceRepository>(),
      ),
    );
  }
}
```

**Package:** `get_it: ^9.2.1` only — no `injectable`, no `build_runner`, no code generation.
**License:** MIT. **Publisher:** verified (`flutter-it.dev`).
**Maintenance:** active.

---

### N-10 · `_openSocket(Uri)` duplicated across LG and Samsung clients *(informational — deferred to 4.6)*

**Files:** `lg_websocket_transport_client.dart:541`, `samsung_websocket_transport_client.dart:285`

Both implement wss-vs-ws branching with `HttpClient`. The difference is intentional: LG
accepts any certificate; Samsung delegates to `SamsungTlsTrustStore`. Unification is not
recommended. Revisit when task 4.6 introduces a third transport client.

---

### N-11 · `TransportClient` is an empty marker interface *(informational — deferred to 4.6)*

**File:** `lib/remote_control/data/adapters/transport_client.dart`

No contract, no polymorphic consumers. All real transport abstractions are brand-specific
(`LgTransportClient`, `SamsungTransportClient`, `HisenseTransportClient`). If task 4.6 adds
`Stream<ConnectionState>` to a shared transport contract, this interface is the natural home.

---

## Execution Notes

- R-03 and N-02 are safe to execute independently in any order.
- R-09 and N-01 can be combined: `TvBrand.displayName` and the Hisense adapter footgun are
  adjacent concerns that land cleanly in one commit.
- N-03 and N-04 must be addressed together — the dispatch map and toggle abstraction are
  tightly coupled in `LgWebSocketTransportClient.sendKey()`.
- N-05 and N-06 are low-risk and can land in any order, independently of each other.
- R-11 touches a public interface; run the full test suite after.
- N-07 is a prerequisite for N-09; extract the composition root before introducing the DI
  container (or skip N-07 and go straight to N-09 if the DI path is confirmed).
- N-08 is independent and can land in any PR.
- N-09 (DI introduction) is the largest change in Branch 2; land last, after all other
  structural work is stable.
- N-10 and N-11 are informational; no action until task 4.6.
- Execution order suggestion: N-05 → N-06 → N-02 → R-03 → R-09+N-01 → N-03+N-04 → R-11 → N-08 → N-07 → N-09.
