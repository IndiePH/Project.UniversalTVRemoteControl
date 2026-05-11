# Changelog

This changelog provides a quick summary of product and implementation direction updates.
Keep entries short and append new updates at the top.

## 2026-05-11

### Added
- Streaming app launch for Netflix, Prime Video, Disney+, and YouTube across all TV adapters;
  Android TV uses `RemoteAppLinkLaunchRequest` (proto field 90, `market://launch?id=<packageName>`)
  since these apps cannot be opened via key codes; adds `sendAppLink` to the transport interface
  and TCP client; YouTube is also wired through all other adapters via key mapper
- Android TV remote control handshake: implements the server-initiated 3-step sequence required
  before commands can be sent on port 6466 (`RemoteConfigure → RemoteSetActive echo →
  RemoteStart`); client sends feature bitmask `active=623` on the active step; adds
  `RemoteDeviceInfo`, `RemoteConfigure` (field 1), and `RemoteStart` (field 40) to `RemoteMessage`
- `AndroidTvHandshakeTracer` extracts diagnostic state from `AndroidTvTcpTransportClient` (SRP);
  injected via constructor; instantiated only in debug builds for zero production overhead

### Fixed
- LG: fixed re-pairing failure when re-pairing after a cancelled attempt

## 2026-05-07

### Added
- `PinFormat` enum (`fourDigitNumeric` / `sixCharHex`) as a domain value in `TvCapabilities`;
  carried through `CommandDispatchResult.pinRequired` and coordinator `promptPin` callback so the
  UI derives PIN format from the domain, not the brand; PIN dialog now accepts 6-char hex input
  for Android TV POLO protocol
- `cancelPairing()` added to `TvBrandAdapter` (default no-op), `RemoteCommandService`, and all
  transport layers (Android TV, LG, Samsung); OS back-button press during pairing now
  error-completes any blocked `Completer`s, cancels socket subscriptions, and clears state maps
  before page pop — prevents cancel-then-re-pair race that would corrupt the new session

## 2026-05-06 (continued)

### Added
- Android TV — Task 9 remote-control transport: completes `AndroidTvTcpTransportClient`
  - `connect()` is now dual-mode: checks for stored server cert via
    `AndroidTvCertificateStore.serverRsaComponents`; routes to port 6467 (pairing) if no
    cert, or port 6466 (remote control) if paired; idempotent on the remote path
  - Remote control socket (port 6466): mutual TLS with client cert + `onBadCertificate`
    accept; sends `RemoteSetActive(active:1)` immediately after connect
  - Wire framing on port 6466: protobuf varint (same as port 6467 — goal file said
    "4-byte big-endian" but base.py confirms varint for both channels)
  - `sendKey(keyCode)`: sends `RemoteMessage { remoteKeyInject { keyCode, direction:SHORT } }`
  - `sendText(text)`: sends `RemoteMessage { remoteImeBatchEdit { imeCounter, fieldCounter,
    editInfo:[{insert:1, textFieldStatus:{start:len-1,end:len-1,value:text}}] } }`;
    counters tracked from TV's inbound `RemoteImeBatchEdit` messages
  - Keepalive: responds to `RemotePingRequest` with `RemotePingResponse { val1: echo }`;
    TV pings every 5 s; connection closes after ~16 s without response (3 unanswered pings)
  - Reconnect: on unexpected socket close, emits disconnected → connecting, waits 3 s,
    then retries `_connectRemote`; guarded by `_remoteActive` set so `clearPairing()` 
    (which removes the device from the set before destroying the socket) does not trigger
    a reconnect loop
  - `clearPairing()` updated: clears `_remoteActive` flag, tears down both pairing and
    remote sockets, clears stored cert, emits disconnected
  - `RemoteControlDiConfig` (prod): registers `AndroidTvCertificateStore` singleton and
    wires `AndroidTvTcpTransportClient` (replacing `FakeAndroidTvTransportClient`);
    `DebugRemoteControlDiConfig` retains the fake

- Android TV — Task 8 pairing transport: `AndroidTvTcpTransportClient` (pairing flow only;
  Task 9 completes it with the remote-control flow)
  - Connects to port 6467 with mutual TLS (`SecureSocket`, client cert from
    `AndroidTvCertificateStore`); accepts any server cert and captures the peer cert DER
    for the pairing secret formula
  - Wire framing: protobuf varint length prefix (verified from protocol source — the goal
    file had warned "likely 4-byte big-endian"; varint is the confirmed format)
  - Pairing state machine: `pairing_request_ack` → send `options` (HEXADECIMAL/6) →
    TV sends `options` → send `configuration` (HEXADECIMAL/6, INPUT role) →
    TV sends `configuration_ack` → `connect()` returns (TV now shows PIN)
  - Service name `"atvremote"` (verified from protocol source; goal file had
    `"androidtvremote2"`)
  - `submitPairingCode(code)`: SHA-256 secret formula over client + server RSA components
    + last 4 hex chars of the 6-char PIN; includes local checksum verify (first byte of
    digest == first two hex chars) to catch user input errors before the TV round-trip
  - Server cert persisted to disk only after confirmed `secret_ack STATUS_OK`
  - `probe(host)`: plain TCP connect to port 6466 with 3-second timeout
  - `clearPairing`: deletes stored server cert via `AndroidTvCertificateStore.clearServerCert`
  - `sendKey`/`sendText`: throw `UnimplementedError` (Task 9 stubs)
  - Follows `hostResolver` injection pattern from `LgWebSocketTransportClient`
- `AndroidTvCertificateStore`: added `extractRsaFromDer(Uint8List)` (public static, for
  transport client to parse peer cert at connect time) and `clearServerCert(host)` (deletes
  per-host `.cert.der` + `.rsa.json` files)
- New `android_tv_exceptions.dart`: `AndroidTvPairingFailedException`,
  `AndroidTvConnectionException`

### Changed
- Android TV mDNS discovery: raised default timeout from 3 s to 5 s; added a second PTR query
  round that fires only when the first returns empty, handling dropped multicast packets without
  increasing discovery time in the common case
- `CompositeDeviceDiscoveryService`: multicast lock now held for the full scan window (released
  only after all services complete) so SSDP finishing first no longer silences mDNS; per-service
  failures are isolated so one service throwing cannot discard results already collected by siblings

## 2026-05-06

### Added
- Android TV — Task 7 certificate management: `AndroidTvCertificateStore` generates an RSA-2048
  self-signed X.509 client cert + key pair on first launch (via `basic_utils`), persists PEM cert,
  PEM private key, and pre-extracted RSA components (hex JSON) to the app documents directory.
  Exposes `clientContext` (`SecurityContext` with client cert + key for mutual-TLS handshake),
  `clientModulus`/`clientExponent` (BigInt), `storeServerCert` (DER → disk + RSA JSON), and
  `serverRsaComponents` — all inputs to the SHA-256 pairing secret formula
- New dependencies: `basic_utils: ^5.8.2` (RSA key gen, CSR, self-signed cert via `X509Utils`),
  `pointycastle: ^4.0.0` (direct ASN.1 parsing for server cert RSA extraction)

### Fixed
- Android TV pairing strings (`pairingAndroidTvProgressHint`, `pairingAndroidTvPreStep0/1`)
  restored to `app_en.arb`; Task 4 had added them directly to the generated files, causing
  them to be wiped by the next `flutter gen-l10n` run; `FakeLocalizedStrings` updated with
  the three missing getters

### Conventions
- **Localization:** all user-facing strings must be added to `lib/l10n/app_en.arb` first —
  never edit the generated `app_localizations.dart` / `app_localizations_en.dart` directly.
  Run `flutter gen-l10n` after updating the ARB. Also add the corresponding getter to
  `test/fakes/fake_localized_strings.dart` so the test layer compiles.

## 2026-05-05

### Added
- Android TV — Task 5 mDNS discovery: `MdnsDeviceDiscoveryService` scans for
  `_androidtvremote2._tcp` services and emits `TvDevice` entries with `brand: TvBrand.androidTv`;
  composed with the existing SSDP service via new `CompositeDeviceDiscoveryService` so both run
  in parallel — no changes to the discovery UI layer
- Android TV — Task 6 protobuf message types: hand-written `GeneratedMessage` subclasses for
  the remote channel (`RemoteMessage`, `RemoteKeyInject`, `RemoteSetActive`,
  `RemotePingRequest/Response`, `RemoteImeKeyInject`) and the pairing channel (`OuterMessage`,
  `PairingRequest/Ack`, `Options`, `Configuration/Ack`, `Secret/SecretAck`, `Status` enum);
  all messages wire-framed with a 4-byte big-endian length prefix
- New dependencies: `multicast_dns: ^0.3.3` (Task 5), `protobuf: ^3.1.0` (Task 6)

## 2026-05-04

### Added
- Android TV adapter foundation (Tasks 1–4): full `AndroidTvAdapter` peer to `LgAdapter`,
  `SamsungAdapter`, and `HisenseAdapter`; v2 protocol only (`_androidtvremote2._tcp`,
  ports 6466/6467, protobuf + mutual TLS); v1 is explicitly excluded:
  - **Task 1** — domain foundation: `TvBrand.androidTv` enum value; `TvCapabilities` entry
    (`keyCommands`, `powerControl`, `pinPairing`); catch-all variant-resolution registry entry;
    fake discovery device; `textInput` capability flag
  - **Task 2** — `AndroidTvKeyMapper` maps all `RemoteCommand` values to verified `RemoteKeyCode`
    integers from `remotemessage.proto` (305-value enum); unsupported shortcuts return empty —
    no invented codes
  - **Task 3** — `AndroidTvTransportClient` abstract interface (connect, submitPairingCode,
    sendKey, sendText, probe, clearPairing, queryDeviceInfo, watchConnectionState);
    `FakeAndroidTvTransportClient` test double in `lib/remote_control/debug/`
  - **Task 4** — `AndroidTvAdapter` wired into adapter registry and both DI configs (prod + debug);
    pre-pairing steps and pairing progress hint registered; localized strings added
    (`pairingAndroidTvPreStep0/1`, `pairingAndroidTvProgressHint`)

## 2026-04-29 *(continued)*

### Fixed
- Removed compile-time transport default from the debug sheet to avoid conflicts with the
  runtime toggle
- Refined pair button hint styling in the status panel

## 2026-04-29

### Added
- Unpaired-user guidance on the remote screen: disabled grid interactions now set a focused status
  prompt (`Pair a TV first.`), and the pair button receives a temporary blinking highlight to direct
  users into the pairing flow before sending remote actions
- New widget coverage for debug runtime behavior: fake-transport toggle keeps the debug sheet open,
  fake-discovery devices appear in pairing after toggle, and copy-log action keeps sheet open when
  no logs exist

### Changed
- Debug runtime toggle flow now aligns pairing discovery with the active fake/real transport
  override, without forcing an app restart
- Debug discovery defaults to real SSDP in debug DI wiring so LAN scans work during development;
  fake discovery is now selected at runtime when fake transport mode is enabled
- Hisense transport naming/file structure normalized:
  `real_hisense_transport_client.dart` -> `hisense_mqtt_transport_client.dart`, and fake client moved
  to `lib/remote_control/debug/fake_hisense_transport_client.dart` for consistency with other brands
- Remote power control keeps neutral styling while no active TV is paired (red power emphasis now
  appears only when controls are active)
- Debug-sheet copy-log feedback switched to overlay toast behavior and improved fake/real transport
  subtitle messaging

## 2026-04-28

### Added
- Localization infrastructure: `flutter_localizations` + `intl` + ARB codegen; `l10n.yaml`,
  `lib/l10n/app_en.arb` (all user-facing English strings), generated `AppLocalizations` wired
  into `MaterialApp` with `localizationsDelegates` and `supportedLocales`
- Flat `LocalizedStrings` abstract interface (`lib/app/localized_strings.dart`) with name-prefix
  grouping (`pairing*`, `remote*`); `AppLocalizedStrings` concrete backed by generated class via
  `static late AppLocalizations _l10n` updated in `MaterialApp.builder`; registered as
  `sl.registerSingleton<LocalizedStrings>()`
- `ValueNotifier<Locale>` registered in DI; `MaterialApp.locale` reacts to it — enables runtime
  locale switching without restart (settings cog / language selector deferred to a future branch)
- `FakeLocalizedStrings` test double (`test/fakes/fake_localized_strings.dart`) for unit-testing
  services and registries without Flutter/`AppLocalizations` machinery
- New unit tests: `pairing_progress_hint_registry_test.dart`,
  `pre_pairing_steps_registry_test.dart`

### Changed
- All user-facing strings in `BrandRoutedRemoteCommandService`,
  `DefaultPairingProgressHintRegistry`, and `DefaultPrePairingStepsRegistry` extracted to
  `app_en.arb`; each class receives `required LocalizedStrings localizedStrings` via constructor
  injection and delegates to it
- `DefaultPrePairingStepsRegistry` step arrays use numbered ARB keys per brand
  (`pairingLgPreStep0`, …) — ARB has no native array type
- All presentation-layer string literals in `lib/remote_control/presentation/` and `lib/app/`
  replaced with `AppLocalizations.of(context)!` lookups; `DateFormat.yMd().add_Hm()` replaces
  manual `formatTwoDigits` for locale-aware date/time rendering
- `TextInputCompatibilityException` now carries `TextCompatibilityError` enum instead of a
  pre-formatted string; `BrandRoutedRemoteCommandService` resolves it to a localized string at
  the catch site
- Lane tests and `brand_routed_remote_command_service_test.dart` updated to inject
  `FakeLocalizedStrings` via constructor

### Removed
- Dead code `PairingPageDialogs.confirmActiveRemoval` (never called)
- `two_digit_format.dart` imports from `pairing_page_sections.dart` and
  `pairing_page_dialogs.dart` (superseded by `DateFormat`)

### Notes
- English only in this branch; adding a second locale is a single `.arb` file — no code changes
- `kRemoteLayoutItemDefinitions` const list excluded from localization (revisit if second locale added)
- Debug/dev-only strings not extracted; visual smoke test (task 4.3) still pending

## 2026-04-27

### Changed
- Branch 4 remote-screen UX update: moved remote selection to a compact header `remote+wifi` control and removed the old `pair` tile from the editable grid
- Added no-TV onboarding hint (`Connect a TV to begin`) and disabled command/search controls when no active TV is selected; remote-selection + settings remain available
- Added brand-aware default layout filtering based on supported commands/capabilities, while still honoring persisted user layout overrides
- Added normalized `Stream<ConnectionState>` flow across transport interfaces, adapters, and `RemoteCommandService`; remote header now shows live connection state
- Collapsed `TvBrandCapabilities` (extension on `TvBrand`) and `TvModelCapabilityRegistry` (injectable interface + predicate-driven list) into a single `TvCapabilities` instance class with a `const` constructor and a static `_map` keyed on `(TvBrand, String)` record tuples
- `capabilitiesFor(brand, [variant])` falls back to the brand's default-variant entry when an unknown variant is supplied — variant resolution stays clean even for devices paired on older builds
- `TvDevice.fromJson` capability fallback is now variant-aware: restores `capabilitiesFor(brand, protocolVariant)` instead of the old brand-only `defaultCapabilities`
- `BrandRoutedRemoteCommandService` loses the `capabilityRegistry` constructor parameter; capability lookup is now the inline `const TvCapabilities().capabilitiesFor(device.brand, variant)` pattern — consistent with all other call sites (SSDP discovery, pairing page, `fromJson`) that cannot receive injection
- Removed `TvModelCapabilityRegistry` singleton registration from `remote_control_di_config.dart`
- Updated `references/guide-adding-protocol-variant.md`: replaced `TvModelCapabilityRegistry` section with `TvCapabilities` section; updated flow diagram, Step 1–4 examples, checklist, and added a design note explaining the map-over-predicates choice

### Added
- Branch 4 regression coverage updates for remote header selection flow, pre-pairing disabled controls, and transport connection-state contract stubs in lane/widget tests
- `TvCapabilities` (`lib/remote_control/domain/models/tv_capabilities.dart`) — replaces both deleted files
- `tv_capabilities_test.dart`: brand default, unknown-variant fallback, and non-empty coverage for every registered brand

### Removed
- `lib/remote_control/domain/models/tv_brand_capabilities.dart`
- `lib/remote_control/domain/models/tv_model_capability_registry.dart`

## 2026-04-26

### Added
- Replaced chevron on paired TV rows with an info (ⓘ) button; tapping shows a dialog with name, brand, model, variant, pairing date, and last known IP (task 3.8e)
- Greyed-out left-chevron hint on paired TV rows to indicate swipe-to-delete affordance

### Fixed
- Search loading spinner now shown even when discovered list already has items; list clears on each new scan (task 3.8a)
- Tapping a paired TV now closes the selection screen immediately instead of re-entering the pairing flow (task 3.8b)
- Swipe-to-delete no longer shows a second "type REMOVE" confirmation; single dialog only (task 3.8c)
- Wifi reachability icon on paired TVs re-probes on every search instead of showing the initial result forever (task 3.8d)

### Added
- Pre-pairing prompt screen before initiating pairing flow
- Pairing outcome dialog and progress hint registry (task 3.2)
- Grouped scrollable paired-TV list with swipe-to-delete (task 3.3)
- Option-3 FAB layout with manual-add modal sheet (task 3.4)
- Per-TV online indicator via TCP reachability probe (task 3.5)
- Rename paired TV from the selection list (task 3.6)
- Paired TV sub-text showing brand, model, and pairing date (task 3.7)
- Brand-dependent capabilities, LG adapter, and refactor across transport/command layers (PR #5)

### Changed
- Consolidated port literals into named constants in transport clients
- Updated file structure to follow project convention

### Fixed
- Corrected stale message assertions in LG lane tests

## 2026-04-25

### Changed
- Introduced `get_it` DI container with `IDiConfig`/`DiBootstrap` pattern; split env-specific DI configs; removed transport concepts from presentation layer
- Registered transport clients in DI; collapsed duplicate host resolvers
- Introduced `Result` base class (`lib/remote_control/application/result.dart`) as the standard return type for all operation results; `CommandDispatchResult` extends it with `CommandOutcome` enum and `getOutcome()`
- Added `MessageHandler.sanitize` for env-aware error verbosity (hides exception detail in production)
- Replaced `sendKey` if/else chain with `TransportCommand`/`TransportCommandFactory` Command pattern; unified toggle state handling
- Generalized `TransportLogReader` as an application-layer port with `NoopTransportLogReader` default; unified Samsung WebSocket `_connectWith` method
- Made `HisenseAdapter.transportClient` required; consolidated `TVBrand` properties
- Deleted duplicate `SamsungKeyMapper.keyCodeFor`; relocated `formatTwoDigits` to `lib/utils` to fix downward layer dependency
- refactor - renamed hisense related method in pairing_page_coordinator.dart

### Added
- Unit tests for strategy map routing in `BrandRoutedRemoteCommandService`
- Wire FlutterError.onError and runZonedGuarded in main.dart
- Per device settings and capabilities. see references/guide-adding-protocol-variant.md
- soft-restart app on use fake toggle

### Conventions
- DI configuration and runtime are now decoupled: `IDiConfig` implementations declare bindings; `DiBootstrap` selects configs by `AppEnvironment`; remote control bindings live in `lib/remote_control/configurations/remote_control_di_config.dart`
- `Result` (`lib/remote_control/application/result.dart`) is the abstract base for all operation results; use `Result.success()` / `Result.failure()` named constructors; consumers use `MessageHandler.sanitize(result)` for safe display strings

## 2026-04-24

### Changed

- Reorganized lib directory structure
  - refactor(structure): flatten lib/ to feature-named top-level dirs (TVREMOTE branch-1)
  - Remove lib/src/ wrapper and lib/src/features/ nesting. Move:
    - lib/src/app/ → lib/app/
    - lib/src/features/remote_control/ → lib/remote_control/
    - lib/src/theme/ → lib/theme/
    - Mirror test/lib/src/features/remote_control/ → test/lib/remote_control/.

## 2026-04-23

### Added

- feature: LG remote adapter [TVREMOTE-39,TVREMOTE-42, TVREMOTE-45 TVREMOTE-47] (PR #2)
- remove Real or real_ prefix in class/file names (it is assumed real unless named with mock or fake)

## 2026-04-20

### Changed
- Workspace hygiene (**TVREMOTE-1**): root `.gitignore` ignores `__pycache__/`; `references/implementation_tasks.md` Status Tracker records verification of existing ignore rules for `.dart_tool/`, `build/`, platform `Flutter/ephemeral`, and clean diffs for tracked `linux/flutter/generated_plugins.cmake` and `windows/flutter/generated_plugins.cmake`.
- Saved-device fallback test coverage (**TVREMOTE-8**): widget tests now cover active-device removal fallback and non-active last-used removal fallback behavior.
- Transport abstraction follow-up (**TVREMOTE-52**, **TVREMOTE-53**): added shared transport marker + required event stream contracts and wired standardized transport events across Samsung/Hisense fake+real clients.
- Onboarding/troubleshooting guidance (**TVREMOTE-17**): pairing page now exposes a non-intrusive top-right help action (`?`) that opens permission/network and "cannot find TV" guidance, with corresponding widget coverage.
- Layout editor SRP pass: `RemoteLayoutEditor` delegates to `RemoteLayoutEditorGridGeometry`
  (cell sizing + occupancy + validation footprints), `RemoteLayoutEditGridPainter` (grid lines),
  `RemoteLayoutEditorItemPreview` (dpad/rocker/icon tiles), and `RemoteLayoutEditorDragSession`
  (anchors, hover highlight, drop resolution wiring); the stateful widget keeps the `Stack` /
  `DragTarget` / `Draggable` tree and header chrome.
- Samsung real transport SRP pass: `RealSamsungTransportClient` now composes
  `RealSamsungPairingTokenStore` (host token + TV-approval waiters),
  `RealSamsungRemoteTextSession` (IME / app-context state + `watchRemoteTextInputReady`),
  `RealSamsungTransportLogging` (logcat + file outbound summaries),
  `RealSamsungWsHandshake` (connect completer), and `samsung_transport_authorization.dart`;
  socket open/bind/close and outbound key/text framing stay in the client.
- Remote-home SRP decomposition pass:
  - extracted focused presentation widgets from `RemoteHomePage`:
    `RemoteTextEntrySheet`, `RemoteHomeStatusPanel`, `RemoteHomeAppBarActions`,
    `RemoteHomeDebugSheet`, `RemoteHomeRemoteGrid`, and `RemoteHomeActions`
  - extracted keyboard-availability policy into
    `remote_keyboard_availability.dart` (`RemoteKeyboardAvailability`) and
    kept a shared user-facing unavailable message + concise debug log mapping
  - behavior is preserved; refactor reduces `RemoteHomePage` UI/build concerns
- Pairing-page SRP decomposition pass:
  - `PairingPageCoordinator`, `PairingPageData`, `PairingPageDialogs` (including Hisense PIN prompt),
    `PairingPageViewState`, and `pairing_page_sections.dart` (`PairingSavedDevicesSection`,
    `PairingDiscoveryList`, `PairingManualAddSection`, `PairingBusyOverlay`, `PairingActionButton`)
  - `RemoteActionButton` renamed to `PairingActionButton` and colocated with pairing sections
- Layout editor: drag/drop and swap resolution live in `RemoteLayoutDropResolver` (`remote_layout_drop_resolver.dart`); swap keeps the dragged control at the dropped cell and chooses a non-overlapping footprint-aware placement for the displaced control (direction-prioritized edge candidates around moved/origin footprints).
- Layout editor: removed swap-result snackbars and the copy-last-drag debug header button.
- Docs sync:
  - updated `references/implementation_tasks.md` status tracker + SRP checklist
  - reformatted `references/implementation_tasks.md` with Markdown task lists across Status Tracker, Next Up, milestone backlog, brand-default rules, suggested execution order, definition of done, and final release gate; added a short checklist legend at the top of the plan
  - updated `references/product_specs.md`, `references/universal-tv-remote-info-and-req.md`, and `references/compliance-and-release-requirements.md` to point readers at the checklist-style Status Tracker / Final Release Gate
  - updated `references/goal-oneremote-lib-review.md` Task 3 follow-up note

### Verification
- `dart analyze` on touched layout files and `flutter test` pass after the updates.
- `dart analyze` on touched remote-home and pairing refactor modules passes.
- `dart analyze` (whole project) after Samsung transport partition passes.
- `dart analyze` + `flutter test test/widget_test.dart` after layout editor SRP split pass.
- `flutter test test/widget_test.dart` passes with saved-device removal fallback coverage (active-device removal fallback and non-active last-used removal without REMOVE guard).

## 2026-04-19

### Changed
- Remote app bar controls were clarified:
  - layout edit uses a pencil/check affordance (`Edit layout` / done)
  - debug options moved under a dedicated cog settings action
- Added runtime debug transport override (no rebuild needed):
  - settings sheet can switch fake vs real transport/discovery wiring
  - selected mode persists in `SharedPreferences` and overrides compile-time default when set
- Completed April 2026 lib review dedupe follow-ups:
  - Task 4: brand capabilities now centralized via `TvBrand.defaultCapabilities`
  - Task 5: shared `formatTwoDigits` helper used by both remote and pairing timestamp rendering

### Verification
- `flutter analyze lib` and `flutter test test/widget_test.dart` pass after task updates.

## 2026-04-18

### Added
- Dart documentation convention: `///` class/type purpose where helpful; targeted comments for non-obvious logic, algorithms, and protocol/platform behavior.
- `flutter_multicast_lock`: hold an Android Wi‑Fi multicast lock for the SSDP scan window so M-SEARCH responses on `239.255.255.250` are less likely to be dropped on real devices/APKs.

### Changed
- `SsdpDeviceDiscoveryService`: broader Hisense SSDP hints (`hiview`, `NT` in header probe), extra M-SEARCH `urn:schemas-upnp-org:device:MediaServer:1`; class doc notes Android multicast behavior.
- Planning/docs: `references/implementation_tasks.md` status tracker, `README.md` discovery note, `references/product_specs.md` Wi‑Fi discovery bullet, `references/third_party_licenses.md` for `flutter_multicast_lock`.

### Verification
- `flutter analyze` and `flutter test` pass after multicast-lock integration.

### Changed
- Updated pairing behavior and Samsung authorization flow:
  - pairing now stays on `PairingPage` until async pairing completes (no early return to remote page)
  - pairing page now blocks user input while busy and shows a loading modal
  - Samsung pairing now triggers TV authorization prompt during pairing flow (no extra manual button press required)
  - pairing success is now gated by Samsung token-authenticated session readiness, not just initial socket connect
- Updated remote screen keyboard behavior:
  - set remote `Scaffold` to avoid body resize on IME open so keyboard overlays the app instead of pushing the layout
- Updated Samsung text-input payload flow:
  - corrected `SendInputString` payload shape (`Cmd`=base64 text, `DataOfCmd`=`base64`)
  - added IME priming event and input-end message for broader Samsung model compatibility

### Verification
- `flutter analyze` passes after transport, pairing, and UI changes
- `flutter test` passes after updating pairing status expectations and constructor wiring

### Added
- Optional Samsung transport diagnostics behind `--dart-define=SAMSUNG_TRANSPORT_DEBUG=true`:
  - logs outbound text IME frames (summarized) and inbound WebSocket messages (tag: `samsung_transport`)

### Changed (UX + docs alignment)
- Pairing page: removed the top explanatory banner; pairing rules unchanged (spec / implementation_tasks still describe active-switch + saved devices behavior)
- Layout editor: entering or leaving settings/edit mode no longer overwrites the remote `_status` line (it is not visible while editing); layout reset uses a snackbar for confirmation
- LG: device capabilities and adapter now agree that in-app text send is not implemented yet (avoids false “text sent” when nothing reaches the TV)
- Default real transports are used unless `USE_FAKE_TRANSPORTS=true` (documented in `README.md`)

### Synced Planning
- Refreshed `references/implementation_tasks.md` status tracker and definition of done for LG text-input implementation
- Updated `references/product_specs.md` brand readiness row for LG vs current code reality
- Re-aligned planning to Samsung/LG/Hisense parallel brand-specific tracks
- Added a final release legal/compliance gate in `references/implementation_tasks.md`:
  - license/attribution pass
  - go/no-go record in `references/third_party_licenses.md`

## 2026-04-17

### Changed
- Pairing and saved-device behavior updates:
  - switched scan path from fake provider wiring to local-network SSDP discovery service
  - clarified UX behavior: pairing a new TV switches active control; previously paired TVs remain saved
  - improved active-device remove flow confirmation UX and validated `REMOVE` regression path
  - removed seeded in-memory placeholder saved device (default startup now has no paired TV)

### Verification
- Added/updated widget coverage for:
  - full loop pass (pair discovered TV -> return -> send command)
  - active saved-device removal with typed confirmation

## 2026-04-17

### Changed
- Updated remote layout/editor baseline and status:
  - increased grid from `5x8` to `5x9`
  - updated default control coordinates to the latest requested arrangement
  - kept play/pause as a compact `1x1` control with side-by-side icons (left play, right pause)
  - updated search control to `5x1` with `4x1` text field + right-side icon action
  - restored channel/volume rocker controls in the remote canvas
  - added directional d-pad arrow padding adjustments for visual centering

### Notes
- A transient Android Gradle/Kotlin incremental cache failure was observed and resolved by rerunning the build; no product code rollback was required.

## 2026-04-17

### Changed
- Clarified `references/third_party_licenses.md` with explicit internal-only stance:
  - no third-party runtime TV-control dependencies currently used
  - tracker retained for future library evaluations and release audit traceability

## 2026-04-17

### Changed
- Updated `references/third_party_licenses.md` to remove Samsung/LG/Hisense external candidate entries.
- Set current direction to internal adapter implementations only (external libraries deferred).

## 2026-04-17

### Changed
- Updated `references/third_party_licenses.md` with production adoption gating:
  - added explicit Go/No-Go criteria
  - added Go/No-Go status column to verification log

### Notes
- All three candidate libraries remain MIT-licensed, but final adoption status is now tracked as conditional until pinned-version and technical smoke-test checks pass.

## 2026-04-17

### Changed
- Updated `references/third_party_licenses.md` with:
  - explicit "older source / use with caution" guidance
  - a verification log table for license audit tracking

### Notes
- MIT status for Samsung/LG/Hisense candidates is considered commercially compatible with notice compliance, but technical/legal verification is still required at pinned commit/version before release.

## 2026-04-17

### Added
- Added `references/third_party_licenses.md` to track external library license status and commercial-use readiness for Samsung/LG/Hisense candidates.

### Notes
- Documented that no third-party TV-control library is integrated yet; current implementation uses internal adapter stubs and router.

## 2026-04-17

### Added
- Added implementation status tracker section to `references/implementation_tasks.md` with:
  - completed items
  - in-progress items
  - next-up priorities

### Changed
- Updated planning visibility to reflect actual code progress:
  - brand adapter router + capability checks
  - safe dispatch result flow
  - pairing page with fake discovery + manual fallback
  - saved-device management and active-device removal safeguards

## 2026-04-17

### Added
- Added a living brand readiness matrix to `references/product_specs.md` for Samsung, LG, Hisense, and Android TV/Google TV.

### Changed
- Aligned Wi-Fi protocol listing with current MVP focus:
  - Samsung and LG are now explicitly MVP targets
  - Hisense listed as validation-gated MVP best-effort
  - Android TV/Google TV moved to Post-MVP expansion candidate

## 2026-04-17

### Changed
- Updated platform strategy in `references/product_specs.md` to Android MVP with iOS treated as Post-MVP.
- Updated MVP brand focus to Samsung, LG, and Hisense (hardware-available-first testing approach).
- Marked cloud pairing as Post-MVP exploration.
- Updated development phases and MVP scope to reflect Samsung/LG first and Hisense validation gate.

### Notes
- Added guidance to prefer stable open-source/protocol adapters where available:
  - Samsung Tizen WebSocket paths exist
  - LG webOS WebSocket paths exist
  - Hisense VIDAA control exists but is less standardized and requires validation

### Synced Planning
- Updated `references/implementation_tasks.md` milestones and definition of done to align with Samsung/LG/Hisense-first execution and iOS-safe architecture planning.

## 2026-04-17

### Changed
- Removed team workload split content from `references/product_specs.md` per scope simplification.
- Renumbered following sections to keep spec numbering consistent.

## 2026-04-17

### Changed
- Refined `references/product_specs.md` future expansion scope to remain TV-only.
- Marked non-TV remotes and broader smart-home scope as out-of-scope for this project.

### Notes
- Non-TV expansion ideas can be pursued in a separate project.

## 2026-04-17

### Added
- Added text input keyboard capability to `references/product_specs.md` for TV search/forms.
- Included text-input verification in first-time setup flow.
- Added technical note for protocol-level text input support and fallback behavior.

### Synced Planning
- Updated `references/implementation_tasks.md` to include keyboard UI and command payload support for text input.
- Updated definition of done to include text input support on compatible TVs.

## 2026-04-17

### Added
- Created `references/implementation_tasks.md` as a living implementation plan derived from `references/product_specs.md`.
- Defined milestone flow:
  - Foundation
  - Vertical Slice (Android TV first)
  - Expansion (Samsung + multi-device)
  - Polish
- Added cross-cutting tracks for testing, telemetry, and platform considerations.

### Notes
- `references/product_specs.md` remains the current source of truth.
- Plan is intentionally flexible and expected to change during development.
- Prioritization favors speed-to-market with incremental, working slices.

### Next Suggested Update Trigger
- Update this changelog when:
  - MVP scope shifts
  - protocol/device support changes
  - milestone order changes
  - acceptance criteria are tightened or relaxed

