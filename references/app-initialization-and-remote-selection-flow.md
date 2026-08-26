# App Initialization & Remote Selection Flow

A linear walkthrough of what runs, in order, from process start to a working remote
screen — which file hands off to which. Verified by direct source reads, 2026-08-21.
This is descriptive documentation of *current, shipped* behavior — not a proposal.

---

## Quick-reference chain

```
main.dart
  → DiBootstrap.initialize()               (app/configurations/di_bootstrap.dart)
      → RemoteControlDiConfig.configure()  (remote_control/configurations/remote_control_di_config.dart)
      → AppMonetizationDiConfig / FeedbackDiConfig / (Dev)AppDiConfig
  → runApp(OneRemoteApp())                 (app/one_remote_app.dart)
      → MaterialApp(home: RemoteHomePage)  (remote_control/presentation/pages/remote_home_page.dart)
          → _loadInitialDevice()
              ├─ no saved/last-used device → empty state, user must pair
              └─ last-used device exists   → _activateDevice() → remote screen ready

Pairing (user-initiated, whenever no device or user taps "add/switch"):
  remote_home_actions.dart → pushes PairingPage (presentation/pages/pairing_page.dart)
    → _scanDevices() → DeviceDiscoveryService.discover()
    → user picks a result, or types a manual IP (pairing_page_data.dart)
    → PairingPageCoordinator.pairSelectedDevice() (pairing_page_coordinator.dart)
        → RemoteCommandService.preparePairing() (brand_routed_remote_command_service.dart)
            → adapter.preparePairing() + queryDeviceInfo()
            → VariantResolutionRegistry.resolve()
            → TvCapabilities().capabilitiesFor()
            → device.copyWith(...) — "enriched" device
        → DeviceRepository.saveDevice() / setLastUsedDevice() / setLastSuccessfulPairingAt()
    → Navigator pops PairingPage, returns TvDevice
  → RemoteHomePage._activateDevice(device) → remote screen ready
```

---

## Phase 1 — Process entry: `main.dart`

`main()` runs, in this exact order (`main.dart:43-91`):

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. Android only: edge-to-edge system UI mode; then portrait orientation lock (all platforms).
3. `Firebase.initializeApp()`.
4. `AppBuildConfig.environmentForMain()` resolves the `AppEnvironment` (production/development/debug).
5. **`await DiBootstrap.initialize(env)`** — see Phase 2. Everything else in the app depends on this having finished; it's awaited before any UI exists.
6. `AnalyticsService.setCountryAtStartup(locale)`.
7. `ProEntitlementService.applyLastKnownStatusFromCache()` then `refreshFromStore(...)` — Pro status is available (from cache, at least) before the UI builds.
8. Mobile only: `AdConsentCoordinator.prepareForAds()`, then `MobileAds.instance.initialize()` if consent allows.
9. `FlutterError.onError` / `PlatformDispatcher.instance.onError` wired to Crashlytics + `AppDiagnosticsRecorder` + an optional in-app error stream.
10. `runApp(const OneRemoteApp())`.

## Phase 2 — Dependency injection: `di_bootstrap.dart`

`DiBootstrap.initialize(env)` (`di_bootstrap.dart:46-79`):

1. If `GetIt` already has core services registered (repeat init, e.g. tests or `OneRemoteApp.restart()`), resets it first.
2. Fetches/activates `AdRemoteConfigService` (Firebase Remote Config) if mobile ads are supported.
3. Registers app-wide singletons directly: `AppEnvironment`, `AdRemoteConfigService`, `AnalyticsService`, the locale `ValueNotifier`, `LocalizedStrings`, `AppThemeController` (loaded from persisted preference).
4. Picks a list of `IDiConfig` objects via `_configsFor(env)` (`di_bootstrap.dart:26-44`) and calls `.configure(sl, env)` on each, in order:
   - **production:** `RemoteControlDiConfig`, `AppMonetizationDiConfig`, `FeedbackDiConfig`.
   - **development/debug:** `RemoteControlDiConfig` *or* `DebugRemoteControlDiConfig` (chosen by a fake-transport override read from `TransportDebugSettings` or the `USE_FAKE_TRANSPORTS` compile flag), plus `DevAppDiConfig`, `AppMonetizationDiConfig`, `FeedbackDiConfig`.

### Phase 2a — `RemoteControlDiConfig.configure()` (`remote_control_di_config.dart:69-154`)

The registrations relevant to device selection and remotes, in order:

1. `_configureShared()` (`:40-55`): `AppDiagnosticsRecorder`, `DeviceRepository` → `SharedPrefsDeviceRepository`, `LayoutRepository` → `SharedPrefsLayoutRepository`, `PrePairingStepsRegistry`, `PairingProgressHintRegistry`, `VariantResolutionRegistry` → `DefaultVariantResolutionRegistry`.
2. `DeviceDiscoveryService` → `DiagnosticsRecordingDeviceDiscoveryService` wrapping a `CompositeDeviceDiscoveryService` that runs three discovery services together: `SsdpDeviceDiscoveryService`, `MdnsDeviceDiscoveryService`, `RokuSsdpDiscoveryService`.
3. Per-brand pairing/token stores and transport clients: `LgPairingKeyStore`, `SamsungPairingTokenStore`, `SamsungWebSocketTransportClient`, `LgWebSocketTransportClient`, `HisensePairingAuthStore`, `HisenseMqttTransportClient`, `AndroidTvCertificateStore`, `AndroidTvTcpTransportClient`, `RokuHttpTransportClient`, `TclLegacyTransportClient` (real or fake, gated by `TCL_LEGACY_WIFI_ENABLED`).
4. Six adapters constructed and collected into a list (`:126-133`): `SamsungAdapter`, `LgAdapter`, `HisenseAdapter`, `AndroidTvAdapter`, `TclRokuAdapter`, `TclLegacyWifiAdapter`.
5. That adapter list feeds `BrandRoutedRemoteCommandService(adapters, variantRegistry, localizedStrings)` — this is the router every command/pairing call goes through (`_adapterFor(brand, variant)`, per `guide-protocol-variants.md`).
6. `RemoteCommandService` → `DiagnosticsRecordingRemoteCommandService` wrapping that router.
7. `TvConnectionStateService` → `MultiplexedTvConnectionStateService(commandService)`.
8. `TvReachabilityService` → `AdapterTvReachabilityService(adapters)`.

`DebugRemoteControlDiConfig.configure()` (`:174-228`) is a near-identical parallel path — same adapter list and services, but every transport client is a `Fake*TransportClient` instead of a real network client.

## Phase 3 — Root widget: `one_remote_app.dart`

`OneRemoteApp.build()` (`:30-67`) pulls `AppThemeController` and the locale/theme `ValueNotifier`s straight out of `GetIt`, then builds one `MaterialApp`. There is **no named-route table** — `MaterialApp.home` is `RemoteHomePage` directly, constructed with every dependency it needs resolved from `GetIt` right there (`commandService`, `deviceRepository`, `discoveryService`, `layoutRepository`, `proEntitlementService`, `connectionStateService`, `transportLogReaderProvider`, plus `interstitialAdController` and `appEnvironment`). `RemoteHomePage` **is** the app's single screen; pairing and every other page get pushed on top of it via `Navigator`, not routed to separately.

## Phase 4 — `RemoteHomePage` boot (`remote_home_page.dart`)

`initState()` (`:132-141`): registers a lifecycle observer, snapshots Pro status and subscribes to its changes, warms up the interstitial ad controller, then calls `_loadInitialDevice()`.

`_loadInitialDevice()` (`:397-418`):

1. Reads `deviceRepository.getSavedDevices()` and `deviceRepository.getLastUsedDevice()`.
2. **No last-used device** → clears text/connection subscriptions, resets the layout to computed defaults, and the screen renders its empty "connect a TV" state. Nothing auto-navigates to pairing — the user has to tap an explicit action.
3. **Last-used device exists** → sets it as `_activeDevice`, subscribes to text-input-ready and connection-state streams, calls `_loadLayoutForDevice(lastUsed)` (capability filtering + saved layout including command-drawer `LayoutZone`; per-`(brand, variant)` layout overrides per `guide-protocol-variants.md` — no real override authored yet, so this resolves to the global baseline for every device today) — matches `product_specs.md`'s "returning users auto-connect to last used device."

## Phase 5 — Pairing a device (`pairing_page.dart` + `pairing_page_coordinator.dart` + `pairing_page_data.dart`)

Triggered from `remote_home_actions.dart`, which pushes `PairingPage` via `Navigator.of(context).push<TvDevice>(...)` (`:73-86`) — the pushed route returns a `TvDevice?` when it pops, which is how the paired device gets back to `RemoteHomePage`.

`PairingPage.initState()` (`:86-94`) kicks off, concurrently: `_scanDevices()` (calls `DeviceDiscoveryService.discover()` — runs SSDP + mDNS + Roku SSDP together, per Phase 2a #2), `_loadRecentManualIps()`, and `_loadPairingMetadata()`.

The user either taps a discovered result, or types a manual IP (built into a `TvDevice` by `pairing_page_data.dart`). Discovery/pairing now prefer a proven stable `id` with mutable `host` when identity can be established (`goal-persistent-device-identity.md`); IP-derived ids remain the fallback when it cannot.

Selecting a device runs **`PairingPageCoordinator.pairSelectedDevice()`** (`pairing_page_coordinator.dart:24-77`):

1. `commandService.preparePairing(device)` → `BrandRoutedRemoteCommandService.preparePairing()` (`brand_routed_remote_command_service.dart:54-100`), which is exactly the flow `guide-protocol-variants.md` documents:
   - Resolves the adapter for `(device.brand, device.protocolVariant)` — at this point `protocolVariant` is still whatever default the discovery service stamped, not yet the real resolved variant.
   - `adapter.preparePairing(device)` — protocol-specific handshake start.
   - `adapter.queryDeviceInfo(device)` → `TvDeviceInfo?`.
   - `VariantResolutionRegistry.resolve(brand, info)` → the real variant string.
   - `TvCapabilities().capabilitiesFor(brand, variant)` → the capability set.
   - `device.copyWith(capabilities, protocolVariant: variant, modelIdentifier: info?.modelIdentifier)` → the "enriched" device — this is the point where a device transitions from "just discovered" to "known brand+variant+capabilities."
   - If capabilities include `pinPairing`, returns `pinRequired` — the coordinator loops, prompting for a PIN via `promptPin` and calling `commandService.submitPairingCode` until it succeeds or the user cancels (`pairing_page_coordinator.dart:79-96`).
   - Otherwise returns success immediately with the enriched device.
2. On success: `deviceRepository.saveDevice(enriched)`, `setLastUsedDevice(enriched.id)`, `setLastSuccessfulPairingAt(device.id, now)`.
3. `PairingPage` pops itself, and the enriched `TvDevice` flows back out through the `Navigator.push<TvDevice>` call from Phase 5's entry point.

## Phase 6 — Back on `RemoteHomePage`: activation and ready state

The caller in `remote_home_actions.dart` receives the returned device and calls **`RemoteHomePage._activateDevice(device)`** (`remote_home_page.dart:601-611`) — the same method `_loadInitialDevice` uses for the auto-connect path:

1. Sets `_activeDevice`, marks status `ready`, clears any pairing-hint UI state.
2. Subscribes to text-input-ready and connection-state streams for this device.
3. `_loadLayoutForDevice(device)` — resolves which buttons show and where (capability filtering, saved positions, command-drawer zone). Per-`(brand,variant)` default overrides are wired but the defaults map is still empty.

From here, every button press runs `_send(command)` → `commandService.sendCommand(device, command)` → `BrandRoutedRemoteCommandService._adapterFor(brand, variant)` → that adapter's protocol-specific transport client.

---

## Where related goal docs plug into this flow

- **Per-variant remote layout** (`guide-protocol-variants.md`, "Adding a variant remote layout") — shipped: `_loadLayoutForDevice`'s default source; no real override authored yet, so it resolves to the global baseline for every device today.
- **Command drawer** — shipped: same load path plus layout-editor UI (`LayoutZone.drawer`).
- **`goal-persistent-device-identity.md`** — `id` / `host` created during discovery and Phase 5 pairing (supersedes `goal-stable-device-identifier.md`).

---
