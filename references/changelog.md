# Changelog

This changelog provides a quick summary of product and implementation direction updates.
Keep entries short and append new updates at the top.

> ⚠️ **Standing notice, not a dated entry — check on every changelog update:** any change
> to app startup, DI bootstrap, or the device discovery/pairing/selection flow may make
> `references/app-initialization-and-remote-selection-flow.md` stale. If an entry you're
> adding touches `main.dart`, `di_bootstrap.dart`, `remote_control_di_config.dart`,
> `one_remote_app.dart`, `remote_home_page.dart`'s device-activation path, `pairing_page.dart`,
> `pairing_page_coordinator.dart`, or `pairing_page_data.dart`, flag it to the user and update
> that doc alongside the changelog entry.

## 2026-08-15

### Fixed
- Samsung TV **Deny** / remote-control authorization rejection is a recoverable pairing outcome, not a Crashlytics fatal. `SamsungWebSocketTransportClient.connect` rethrows `SamsungTransportAuthorizationException` (does not wrap it in `StateError`); `BrandRoutedRemoteCommandService.connect` swallows background-connect failures; Samsung/LG/Hisense in-flight cleanup uses `Future.ignore()` instead of `unawaited(f.whenComplete(...))` so the cleanup future cannot leak the same error into the zone.
- Home no longer auto-retries after authorization denial. New `ConnectionState.unauthorized` (`shouldAutoReconnect` is false); label **Allow this remote on your TV**; retry still runs on transient `disconnected` / `error`. App resume does not restart retry while unauthorized. Pairing-page Deny still maps to `CommandDispatchResult.failure`. Remote key send after Deny remains a command failure, not a crash.
- Crashlytics `FlutterError: Zone mismatch` at `runApp` (`c1d5a2f`): `WidgetsFlutterBinding.ensureInitialized()` ran in the root zone while `runApp` ran inside `runZonedGuarded`. `runApp` now runs in the same zone as binding init; `runZonedGuarded` removed. Uncaught async errors stay on `PlatformDispatcher.instance.onError` (Crashlytics + diagnostics / `StreamUnhandledErrorSource`).

### Verification
- `flutter test` on `connection_state_test.dart`, `brand_routed_remote_command_service_test.dart`, `samsung_test_lane_test.dart`, `widget_test.dart`, `lg_test_lane_test.dart`, `hisense_test_lane_test.dart` — all passed (includes unauthorized reconnect/UI coverage and swallowed background `connect()`).
- `flutter analyze lib/main.dart` — no issues.

## 2026-07-22

### Changed
- README overhaul: replaced Flutter template **Getting Started** with project overview, supported-brand table, repo layout, developer quick start, connection/reconnect behavior (`TvConnectionStateService` / `TvReachabilityService`), expanded `--dart-define` catalog (LG default transport, TCL gate, monetization/compliance), Firebase Pro validation pointer, and documentation index linking `references/`.
- `references/product_specs.md` §6 and `references/implementation_tasks.md` cross-link README for developer onboarding.

## 2026-06-29

### Fixed
- Select-a-remote connection indicator regression (`34788d0`): `_PairedTvConnectionIndicator` converted back to a `StatefulWidget` driven by `TvReachabilityService.isReachable` (TCP probe, port 6466) instead of a live `TvConnectionStateService` stream. Non-active paired devices no longer hard-code disconnected — all rows probe independently of which device is active on the home page. `PairedTvListItem`, `PairingPage`, and `RemoteHomeActions.openPairing` wired to `TvReachabilityService` (already DI-registered; no new registrations). `scanCount` re-key already re-fires the probe on each FAB scan tap — no additional polling added.

### Verification
- `flutter test test/lib/remote_control/presentation/pages/pairing_page_test.dart test/widget_test.dart` — 48 tests passed; 4 new tests added in `pairing_page_test.dart` `connection indicator` group (spinner while pending, wifi on reachable, wifi_off on unreachable, all paired devices probed including non-active).

### Added
- Fix 2a — `connect()` added to `TvBrandAdapter` interface and `BrandRoutedRemoteCommandService`; `LgAdapter`, `SamsungAdapter`, and `HisenseAdapter` each gain a `Map<String, Future<void>> _connectInFlight` in-flight guard so concurrent callers sharing the same device ID join the same transport future instead of opening duplicate connections.
- Fix 2b — `RemoteHomePage._subscribeConnectionState` fires `unawaited(commandService.connect(device))` immediately after subscribing to `watchConnectionState`; `_startConnectionRetry` starts a `Timer.periodic(5 s)` reconnect loop on disconnect; `_stopConnectionRetry` cancels it on connected/error; `dispose` always cancels the timer; `AppLifecycleState` pauses and resumes the retry on background/foreground transitions.

### Fixed
- Concurrent-connect regression (Fix 2a timing): the initial in-flight guard returned `_transportClient.connect().whenComplete(cleanup)` from `connect()`, adding an extra microtask hop when `watchConnectionState` awaited it. This broke the widget test `pairs to discovered TV and sends command from remote` — `_connectionState` was not yet `connected` when the power button was tapped. Fixed by returning the transport future directly from `connect()` and scheduling cleanup as a fire-and-forget side effect via `unawaited(f.whenComplete(...))`, preserving original 1-hop timing while keeping the race guard intact.

### Fixed
- Spurious LG pairing popup on active TV (Bug 1): `_startConnectionRetry` in `RemoteHomePage` now guards each timer tick with `!mounted || ModalRoute.of(context)?.isCurrent != true` — skips `connect()` while any route is on top of the home page (e.g. pairing page, settings). When the user returns, `isCurrent` is `true` again and the next tick resumes normally. Eliminates the race where the 5 s retry fired `connect(activeTV)` without a stored key while `preparePairing(newTV)` was in progress, causing an unwanted SSAP approval popup on the active TV.

### Verification
- `flutter test` — 453 tests passed (includes 3 new concurrent-connect tests in `lg_test_lane_test.dart`, `samsung_test_lane_test.dart`, `hisense_test_lane_test.dart`; 2 new widget tests `retry timer skips connect while another route is on top` and `retry timer resumes connect after pushed route pops` in `widget_test.dart`).

### Changed
- Android Gradle: `kotlin.incremental=false` in `android/gradle.properties` (documented in README Building APKs) to avoid Kotlin incremental cache failures when the project and Pub cache are on different drives.

## 2026-06-07

### Added
- Per-host pairing credential persistence (`54861ee`): `HostScopedSecretPersistence` + `SecureHostScopedSecretPersistence` via `flutter_secure_storage`; Samsung `SamsungPairingTokenStore`, Hisense `HisensePairingAuthStore`, and LG `LgPairingKeyStore` retain tokens across app restarts; tests in `samsung_pairing_token_store_test.dart`, `hisense_pairing_auth_store_test.dart`, `lg_pairing_key_store_test.dart`.
- Connection state service (`34788d0`, partial **TVREMOTE-24**): `TvConnectionStateService` + `MultiplexedTvConnectionStateService` multiplex one upstream transport stream per device id; `TvConnectionStateIndicator` + `connection_state_presentation.dart` shared labels/icons.
- Device policy modules (`34788d0`, extends **TVREMOTE-19**): `FreeTierDevicePolicy`, `ProDeviceSwitchPolicy`, `SavedDeviceDisplayOrdering`, `TvDeviceSelection` extracted from `RemoteHomePage` and `PairingPage`; unit tests for each policy plus `multiplexed_tv_connection_state_service_test.dart`.

### Changed
- Home paired-TV / active-device UI used live transport connection state instead of one-shot TCP reachability probes (`34788d0`). **Superseded for select-a-remote / pairing-list rows** by the 2026-06-29 reachability-indicator fix (`e1af1b9`): those rows probe via `TvReachabilityService` again; home active connection remains on `TvConnectionStateService`.
- `SecureHostScopedSecretPersistence` uses platform-default `FlutterSecureStorage` (KeyStore AES-GCM / Keychain) instead of legacy `encryptedSharedPreferences` Android option (`34788d0`).
- Widget and pairing tests register `TvConnectionStateService` stubs / multiplexed delegates (`34788d0`).

## 2026-06-04

### Fixed
- Firebase Functions `predeploy` path expansion (`4846b70`, **TVREMOTE-67**): `firebase.json` uses portable `$RESOURCE_DIR` so Firebase CLI expands the functions directory on deploy hosts (replaces Windows `%RESOURCE_DIR%`).

### Changed
- Firebase Functions Pro validation layout (`b65f094`, **TVREMOTE-67**): modular `functions/src/` tree (`handlers/verify-pro-android-purchase.ts`, `android/play-verification.ts`, `pro/catalog.ts`, `entitlement/persist-pro-android.ts`, etc.); `functions/lib/` gitignored; `firebase.json` `predeploy` builds TypeScript before deploy; operator guide updated in `references/goals/goal-pro-receipt-validation-remote-setup.md`.

### Fixed
- Interstitial ads no longer cover user-input overlays (`b65f094`, **TVREMOTE-63** / **TVREMOTE-66**): presentation-block depth on `InterstitialAdController` during Hisense PIN dialog, remote keyboard sheet, and feedback sheet; policy `canShow` respects `isPresentationBlocked`; tests in `interstitial_ad_controller_test.dart` and `interstitial_ad_policy_test.dart`.

## 2026-05-30

### Added
- Settings About section (`05aca51`, **TVREMOTE-26**): remote-home settings sheet shows installed app version via `AppPackageInfoSource.versionLabel` (`settingsAboutSectionTitle` / `settingsAppVersionLabel` l10n).
- Firebase Remote Config ad toggle (`4af3cdc`, **TVREMOTE-63** / **TVREMOTE-26**): `AdRemoteConfigService` reads `test_ads_enabled` to switch banner and interstitial **ad unit IDs** at runtime; production AdMob **app IDs** wired at build time (Android manifest placeholder via `build.gradle.kts`, `AdConfig` constants); `firebase_remote_config` dependency; `test/lib/app/ads/ad_config_test.dart`.
- Android edge-to-edge (`4af3cdc`, **TVREMOTE-26**): `FlutterFragmentActivity` + `enableEdgeToEdge()`; transparent status/navigation bars in `styles.xml`; `SystemChrome.setEnabledSystemUIMode(edgeToEdge)` in `main.dart`; `AppTheme` system overlay icon brightness for SDK 35 Play Console compliance.
- Firebase Analytics + Crashlytics (`bf5d103`): Firebase init at startup; fatal Flutter/platform errors reported to Crashlytics; `AnalyticsService` in DI with Pro entitlement change events and startup locale signal.
- Pro multi-plan IAP + Android receipt validation (`a5259be`, `ab7b395`, **TVREMOTE-66** / **TVREMOTE-67** app lane): `ProProductIds` catalog (weekly/monthly/annual/lifetime); `ProUpgradePage` plan picker with localized labels and price fetch; `ProReceiptValidationService` + Firebase callable `verifyProAndroidPurchase` in `functions/`; Play subscriptionsv2 validation with legacy fallback and reinstall token rebind; restore purchase outcomes; settings Pro status/plan/renewal details; entitlement refresh on app resume.
- Monetization tests expanded: `pro_entitlement_service_test.dart`, `pro_receipt_validation_service_test.dart`, `pro_upgrade_page_test.dart`.

### Changed
- `AdRemoteConfigService` resilience (`05aca51`, **TVREMOTE-63**): split Remote Config settings/defaults from fetch; on fetch failure keep last activated `test_ads_enabled` instead of reverting to test ads; release `minimumFetchInterval` shortened to 1 minute so published toggles apply on next cold start.
- Android Gradle Kotlin DSL (`05aca51`): drop explicit `kotlin-android` plugin; use built-in `kotlin { compilerOptions { jvmTarget = JVM_17 } }` block.
- App version `1.3.2+13` (`05aca51`).
- `AdConfig.shouldUseTestAds`: debug builds always use Google test ad units; release follows Remote Config `test_ads_enabled` (fail-safe default `true`); live unit IDs still overridable via `--dart-define=ADMOB_*`.
- `DiBootstrap.initialize` fetches Remote Config at startup when mobile ads are supported; `AdRemoteConfigService` registered in GetIt and preserved across `OneRemoteApp.restart()`.
- Legal links prefer in-app WebView on mobile (`InAppLegalWebviewPage`, `LegalLinkLauncher`).
- iOS AdMob production app/ad unit IDs in `Info.plist` (`bf5d103`); Android production AdMob app ID via manifest placeholder (`4af3cdc`).
- Android release builds fail when signing keystore is missing (avoids debug-signed release artifacts).
- App version bumps for billing rollout (`1.0.1+3`, `1.3.0+10`).

### Fixed
- Pro upgrade page defers `loadProducts()` to the next microtask so entitlement notifiers are not updated during dialog build (`4af3cdc`, **TVREMOTE-66**).
- Android TV protobuf 6: replace `PbList.createRepeated` with `List` in Android TV remote/pairing message types (`ef8386b`).
- Functions repo hygiene: stop tracking `functions/node_modules`; ignore `functions/.env` while keeping `.env.example` committable (`5b26a78`).

## 2026-05-28

### Fixed
- Fake discovery gating: only show fake pairing devices when fake transports are actually active at runtime; add widget coverage for the non-fake runtime case.

## 2026-05-22

### Added
- Third-party license scan (**TVREMOTE-32**): full direct-dependency table, protocol/asset audit, and release go/no-go in `references/third_party_licenses.md`; Settings → Legal → **Open source licenses** (`showLicensePage` with app version).
- Samsung adapter refinement C1 (**TVREMOTE-38**): `SamsungTransportClient.clearPairing`;
  WebSocket client clears token, cached device info, TLS pins, and sockets;
  `SamsungAdapter.unpairDevice` delegates; fake transport mirrors.
  `SamsungKeyMapper` back command adds `KEY_BACK` alias after `KEY_RETURN`.
  Tests in `samsung_test_lane_test.dart` and `samsung_key_mapper_test.dart` (44
  Samsung-lane tests passed).
- Hisense SSDP fingerprint regression tests (**TVREMOTE-7**): expanded
  `ssdp_brand_inference_test.dart` for `hisense` / `vidaa` / `hiview` headers
  and `nt` probe inclusion.
- Samsung connect device info for validation/debug (**TVREMOTE-14**): cache
  model/firmware/OS from `ms.channel.connect`; `RemoteCommandService.queryDeviceInfo`;
  `TvDeviceDebugInfoPanel` in settings and debug sheets (`SamsungDeviceInfoSnapshot`,
  `samsung_device_info_snapshot_test.dart`).
- Samsung approval-variant physical validation runbook (**TVREMOTE-14**):
  scenarios A–C (first-time approval, token reuse, rejection/timeout recovery),
  code-under-test map, outcome table, and follow-up template in
  `references/samsung_validation_matrix.md`.
- Telemetry/diagnostics C1 (**TVREMOTE-29**): `AppDiagnosticsRecorder`
  (discovery/pairing/command counters + recent events); DI decorators;
  `DiagnosticsSummaryPanel` + copy diagnostics report in debug settings;
  pairing session + unhandled-error hooks.

### Verification
- Third-party license scan (**TVREMOTE-32**): `flutter test` — full suite passed (2026-05-22); `flutter analyze` clean on settings/license touchpoints.
- Telemetry/diagnostics C1 (**TVREMOTE-29**): `flutter test test/lib/app/diagnostics/app_diagnostics_recorder_test.dart` — 1 test passed (2026-05-22).
- Hisense Android SSDP physical validation (**TVREMOTE-7**): Hisense TV —
  SSDP scan, manual-IP pair, PIN flow, keys, reconnect **pass** (2026-05-22)
  in `references/hisense_validation_matrix.md` known-good matrix; fallback
  policy unchanged (manual IP + `TV_HOST_OVERRIDE`; port sweep deferred).
- Samsung approval-variant physical validation (**TVREMOTE-14**): scenarios A–C
  recorded **pass** on Samsung TV (2026-05-22) in
  `references/samsung_validation_matrix.md` approval outcome table; no follow-up
  Jira from matrix.
- Vertical-slice widget/integration coverage (**TVREMOTE-11**): `test/widget_test.dart`
  adds discovery failure + empty-rescan recovery, returning last-used launch with
  command send, and command-dispatch failure surfacing (status + toast).
- CI / environment baseline (**TVREMOTE-31**): `.github/workflows/flutter_ci.yml`
  (format, analyze, test on PRs to `main` / `master` / `develop`);
  `AppBuildConfig` maps Flutter build mode to `AppEnvironment`; README build-profile
  table documents intentional Gradle product-flavor gaps.

### Changed
- Flutter CI (**TVREMOTE-31**): `flutter_ci.yml` adds `qualify` job that skips format/analyze/test when push/PR diff is only under `references/`; `develop` branch triggers restored; README documents skip rule (`ddc1a82`).
- Samsung approval timeout/rejection regression tests (**TVREMOTE-13**): repo AC
  met; Jira **Done** (2026-05-22); `implementation_tasks.md` Jira block aligned.
- Telemetry/diagnostics (**TVREMOTE-29**): Task C1 shipped in repo; Jira **Done**
  (2026-05-22); `implementation_tasks.md` Jira block + Cross-Cutting Task C1 aligned.
- Layout-focused tests (**TVREMOTE-20**): repo AC met; Jira **Done** (2026-05-22);
  `implementation_tasks.md` Jira block aligned.
- `AdConsentCoordinator.isPrivacyOptionsRequired` uses timeout + fallback when the
  Mobile Ads plugin is absent so the settings sheet is not blocked in widget tests.

### Verification (automated)
- `flutter test test/lib/remote_control/presentation/widgets/remote_layout_drop_resolver_test.dart test/lib/remote_control/data/shared_prefs_layout_repository_test.dart test/lib/remote_control/presentation/widgets/remote_layout_grid_constraints_test.dart test/lib/remote_control/presentation/widgets/remote_layout_editor_widget_test.dart` passed (**TVREMOTE-20**; 16 tests; 2026-05-22 impl-start re-verify).
- `flutter test test/lib/remote_control/data/adapters/samsung_test_lane_test.dart test/lib/remote_control/data/adapters/samsung/samsung_pairing_token_store_test.dart` passed (**TVREMOTE-13**; 21 tests; 2026-05-22 re-verify).
- `flutter test test/lib/remote_control/data/ssdp_brand_inference_test.dart` passed
  (**TVREMOTE-7**; 8 tests; 2026-05-22).
- `dart format --output=none --set-exit-if-changed .`, `flutter analyze --fatal-infos`,
  `flutter test` (389 passed, 1 skipped; includes **TVREMOTE-11** widget edge cases).

## 2026-05-21

### Changed
- TCL legacy Wi-Fi variant resolution (**TVREMOTE-70**): `TclProtocolVariants.isLegacyWifi`
  matches exact transport `legacyWifiModelMarker` (replaces substring
  `contains('legacy_wifi')`); TCL catch-all registry entry maps empty device info
  to `tcl_legacy_wifi`; manual pairing uses shared constant; `TvCapabilities`
  exposes `keyCommands` + `powerControl` for `(TvBrand.tcl, defaultProtocolVariant)`.

### Added
- TCL variant resolution unit tests (**TVREMOTE-70**):
  `test/lib/remote_control/data/variant_resolution_registry_test.dart` (marker
  match, TCL catch-all, brand default fallthrough).
- In-app user feedback (**TVREMOTE-68**): `FeedbackSubmissionSheet` entry in
  `RemoteHomeSettingsSheet`; `HttpFeedbackSubmissionService` + `FeedbackConfig`
  (`FEEDBACK_WEBHOOK_URL` / `FEEDBACK_WEBHOOK_TOKEN` via `--dart-define`); operator
  setup in `references/feedback-collection-setup.md`.
- Layout-focused tests (**TVREMOTE-20**): `remote_layout_drop_resolver_test.dart`
  (empty-cell move, bounds reject, multi-control footprint reject, 1x1 swap,
  congested swap reject, anchor offsets); `shared_prefs_layout_repository_test.dart`
  (save/load/overwrite, invalid payload skip); `remote_layout_grid_constraints_test.dart`
  (default `5x9` validation footprints fit with no overlaps); `remote_layout_editor_widget_test.dart`
  (editor chrome + reset invokes `onResetLayout`).
- Discovery brand identification (**TVREMOTE-18**): `inferSsdpTvBrand` /
  `ssdp_brand_inference.dart`; `DiscoveryResultMerger` dedupes parallel scans by
  host IP with Samsung/LG/Hisense priority; `DiscoveredDeviceSupport` tiers with
  limited/experimental subtitles on pairing discovery rows.
- Multi-device quick switch on remote home (**TVREMOTE-19**): tappable device name
  opens `RemoteHomeDeviceSwitcherSheet` with saved TVs; selecting one updates
  active control, per-device layout, and `last_used_device_id`.
- Samsung approval timeout/rejection regression tests (**TVREMOTE-13**):
  `samsung_test_lane_test.dart` (service failure messaging, retry recovery,
  `cancelPairing` delegation) and `samsung_pairing_token_store_test.dart`
  (unauthorized frame, token completion, cancel cleanup).

### Changed
- Multi-device management (**TVREMOTE-19**): Jira **Done** and `implementation_tasks.md`
  aligned with Task 2.3 shipped scope (save/rename/remove, switcher, last-used).
- Default Apps Script feedback webhook rotated in `FeedbackConfig` (deployment
  `AKfycbyYdrlh8oVk1BwA2w5xa6JGW0kPwGSRaSElpqmClz2VyfhPpEX3rRvT3oTPbcS8w4HTWQ`);
  `references/feedback-collection-setup.md` documents 11-column ingest, FILTER
  category views, spam heuristics, migration, and curl smoke test (**TVREMOTE-68**
  app lane; production token/policy still **TVREMOTE-69**).
- Saved-device tap on pairing screen now calls `setLastUsedDevice` before returning
  to remote home so relaunch and switcher stay aligned with the selected TV.

### Verification
- `flutter test test/lib/remote_control/data/variant_resolution_registry_test.dart` passed (**TVREMOTE-70**; 4 tests; post-push 2026-05-21).
- `flutter test test/lib/app/feedback/feedback_config_test.dart` passed (webhook default; post-push 2026-05-21).
- `flutter test test/lib/app/feedback/ test/lib/app/package_info/` passed (**TVREMOTE-68**; 9 tests).
- `flutter test test/lib/remote_control/presentation/widgets/remote_layout_drop_resolver_test.dart test/lib/remote_control/data/shared_prefs_layout_repository_test.dart test/lib/remote_control/presentation/widgets/remote_layout_grid_constraints_test.dart test/lib/remote_control/presentation/widgets/remote_layout_editor_widget_test.dart` passed (**TVREMOTE-20**; 16 tests).
- `flutter test test/widget_test.dart --name "switches active TV"` passed.
- `flutter test test/lib/remote_control/data/ssdp_brand_inference_test.dart test/lib/remote_control/data/discovery_result_merger_test.dart` passed (**TVREMOTE-18**).
- `flutter test test/lib/remote_control/data/adapters/samsung_test_lane_test.dart test/lib/remote_control/data/adapters/samsung/samsung_pairing_token_store_test.dart` passed (**TVREMOTE-13**; 21 tests).

## 2026-05-20

### Added
- Pro IAP app integration (`TVREMOTE-66`, commit `640c702`): `in_app_purchase`,
  `ProEntitlementService` / store + fake repositories, settings sheet purchase +
  restore, banner hidden + layout editor unlocked when entitled.
- Free-tier **interstitial** ads (`TVREMOTE-63` / `TVREMOTE-66`): `InterstitialAdController`,
  `InterstitialAdPolicy`, engagement-gated show after successful remote commands;
  `AdConfig.interstitialAdUnitId` with test IDs and
  `--dart-define=ADMOB_INTERSTITIAL_ANDROID` / `ADMOB_INTERSTITIAL_IOS`.
- **Ad consent** (`TVREMOTE-26`): `AdConsentCoordinator` — UMP via `google_mobile_ads`,
  iOS ATT via `app_tracking_transparency`; `main.dart` runs consent before
  `MobileAds.initialize()`; placements respect `canRequestAds`.
- **Compliance UX**: `AppLegalUrls`, `LegalLinkLauncher`, privacy-policy link and
  UMP privacy-options entry in `RemoteHomeSettingsSheet` (`url_launcher`).
- **Diagnostics** (`TVREMOTE-29`): `AppDiagnosticsRecorder`, discovery/command
  decorators, pairing session counters, `DiagnosticsSummaryPanel` + copy report in
  settings; unhandled errors recorded from `main.dart`.
- **Interaction polish** (`TVREMOTE-28`): `RemotePressFeedback` scale animation +
  `RemoteCommandHapticFeedback` on d-pad, rockers, icon buttons, and grid controls.

### Changed
- Samsung/LG adapters (`TVREMOTE-41`, `TVREMOTE-42`): `watchRemoteTextInputReady`
  no longer side-effects `connect()`; explicit `probeRemoteTextInputReady` for
  connect+probe. Test lanes updated (`TVREMOTE-49`, `TVREMOTE-50`).
- `RemoteHomePage`: connection status sync (`Ready` / `Disconnected`); Pro
  entitlement reloads saved layout; interstitial warm-up tied to Pro + consent;
  debug entitlement toggle + interstitial test hook.
- `PairingPageCoordinator`: records pairing session success/failure into diagnostics.

### Verification
- Not run in this doc-sync pass (working tree uncommitted).

## 2026-05-14

### Changed
- Hisense protocol adapter refinement (`TVREMOTE-40`):
  - **Real-PIN forwarding:** `HisenseMqttTransportClient.submitAuthenticationCode`
    no longer hard-rejects PINs other than the dev value `1234`. The TV-shown
    4-digit PIN is now published verbatim on the VIDAA auth topic and the
    session is marked optimistically authorized (VIDAA MQTT does not expose a
    synchronous reply, so an incorrect PIN surfaces later as silent key drops
    and is recovered through the existing PIN-retry pairing UI). The `1234`
    shortcut remains only in `FakeHisenseTransportClient` for lab/dev runs.
  - **Active reconnect:** `_pollConnectivity` now attempts a single
    non-overlapping `_ensureConnected` for devices that already cleared the
    PIN gate in this session when the MQTT/TCP probe reports the link is
    down (`_reconnectInFlight` guards against piling up concurrent reconnects).
    Devices that were never authorized still rely on the lazy reconnect on
    the next user action.
  - **`unpairDevice` clears MQTT state:** `HisenseTransportClient` gains
    `clearPairing(deviceId:)`; the MQTT implementation disconnects the
    broker session, drops the in-memory `_authorizedDeviceIds` flag, cancels
    the connectivity poll timer, and resets the device-info log gate; the
    fake transport mirrors the cleanup. `HisenseAdapter.unpairDevice` now
    delegates to this, so removing a saved Hisense TV re-enters the PIN
    gate on the next pair attempt instead of resuming a cached auth.
  - **VIDAA key-alias fan-out:** `HisenseAdapter.sendCommand` now publishes
    every key alias returned by `HisenseKeyMapper.keyCodesFor(command)`
    (e.g. `KEY_RETURNS` / `KEY_RETURN` / `KEY_BACK` for `back`,
    `KEY_CHANNELUP` / `KEY_CHSUP` for `channelUp`) instead of only the first
    entry. MQTT `sendkey` is fire-and-forget atMostOnce with no per-key ack
    channel, so this is a firmware-variant tolerance measure: the TV
    silently ignores aliases it does not recognize.
- `test/lib/remote_control/data/adapters/hisense_test_lane_test.dart`: spy
  transports gain `clearPairing` stubs; new coverage for adapter
  `unpairDevice` → transport `clearPairing` delegation and the `back`
  command publishing all three VIDAA aliases in order.

### Added
- `references/hisense_validation_matrix.md` — Hisense Android SSDP runbook
  (TVREMOTE-7): scope, environment template, known-good matrix, and a
  recorded fallback-path decision (manual IP via pairing UI +
  `TV_HOST_OVERRIDE` as primary fallback; active port-`36669` LAN sweep
  deferred until ≥2 validated routers still produce empty Hisense scans on
  real hardware). Mirrors the Samsung validation matrix structure.

### Changed
- `references/implementation_tasks.md` Task 1.1 Hisense re-validation
  bullet now references the new runbook and the fallback decision (still
  unchecked — pending physical-device runs to fill the known-good matrix).

## 2026-05-13

### Added
- Remote home bottom banner ad via new `lib/app/ads/` module:
  - `AdConfig` exposes `supportsMobileAds` + env-aware `bannerAdUnitId(AppEnvironment)`;
    production reads `--dart-define=ADMOB_BANNER_ANDROID` / `ADMOB_BANNER_IOS` and falls
    back to Google's test ad unit IDs; non-mobile/`kIsWeb` paths return `null` so no
    overlay is built
  - `BottomBannerAd` (anchored adaptive banner; renders `SizedBox.shrink()` until
    `onAdLoaded`, dispose-safe across width changes) + `BottomBannerAdPlacement.buildOverlay`
    (`Positioned.fill` + bottom-aligned `SafeArea`); `RemoteHomePage` stacks the overlay
    above the body and skips it when the placement returns `null`
- `google_mobile_ads: ^8.0.0` added to `pubspec.yaml`; `main.dart` calls
  `MobileAds.instance.initialize()` only on Android/iOS (skipped on web/desktop)
- Platform AdMob plumbing (test ids only — swap before release):
  - Android manifest declares
    `com.google.android.gms.ads.APPLICATION_ID = ca-app-pub-3940256099942544~3347511713`
  - iOS `Info.plist` declares `GADApplicationIdentifier` (test) and a placeholder
    `SKAdNetworkItems` entry (`cstr6suwn9.skadnetwork`)
- Shared `RemoteHeaderIconButton` widget so the live remote pair button and the
  layout-editor reset button share an identical bounding box / outline / Material
  shell (prevents the two header surfaces from drifting visually)
- New presentation metrics module under `lib/remote_control/presentation/metrics/`
  consolidates sizing/timing constants that were previously duplicated across
  `RemoteHomePage`, `RemoteHomeStatusPanel`, `RemoteHomeRemoteGrid`,
  `RemoteIconCircleButton`, and `RemoteLayoutEditor`:
  - `remote_layout_button_metrics.dart` — header button + in-grid icon button
    sizing, border widths, cell inset ratio, play/pause pill glyph ratios/boosts
  - `remote_layout_header_metrics.dart` — fixed `kRemoteLayoutHeaderHeight = 106`
    shared by remote home and layout-editor headers (sized to the taller of the
    two so the grid starts at the same vertical position in both modes)
  - `remote_pairing_hint_metrics.dart` — `kRemotePairingHintFadeDuration` cross-fade
    duration shared by the grid pairing-hint `AnimatedSwitcher` and status panel
    blur-when-pair-focus overlay so they stop drifting out of sync

### Changed
- Remote grid lowered from `5x9` to `5x8` so the bottom banner ad has stable real
  estate without shrinking controls or resizing the body when the IME opens;
  `product_specs.md` §3 customization spec, `implementation_tasks.md` SRP tracker,
  and pending widget-test target updated to `5x8`
- Remote `AppBar` tightened to a compact toolbar (`toolbarHeight: 50`) with a thin
  outline divider above and below; `RemoteHomePage.body` now uses a `Stack`
  (`fit: StackFit.expand`) so the banner overlay can render bottom-aligned without
  affecting the editable area's bounds

## 2026-05-11 (continued)

### Added
- Test coverage for `CommandDispatchResult.pinRequired`: `isPinRequired`, `isSuccess`, `pinFormat`
  default and explicit, and message preservation; `PinFormat` forwarding verified through
  `PairingPageCoordinator` (`promptPin` receives format from result) and both adapter lane tests
  (hisense `fourDigitNumeric` via `PinRequiredException`, Android TV `sixCharHex` via capability path)
- `PinFormat.sixCharHex` widget test: PIN dialog shows 6-char label, `maxLength 6`, and
  `visiblePassword` keyboard type when `preparePairing` returns `sixCharHex` format

### Fixed
- 4 failing tests corrected after prior feature additions:
  - `Hisense lane: preparePairing` — assertion updated to `isPinRequired` (hisense canonical
    capabilities now include `pinPairing`, so `preparePairing` returns `pinRequired` not `success`)
  - `disables remote actions when no active device` — expected status updated to `'Pair a TV first.'`
    (commit `9418a8b` changed button tap with no device to call `_onDisabledGridInteraction`)
  - `pairs to discovered TV` and `clears active device` widget tests — registered missing
    `AppEnvironment` singleton so `RemoteHomeActions.openPairing` GetIt lookup succeeds
- `fourDigitPin` → `pinCode` parameter rename propagated to all test stub `submitPairingCode`
  implementations and call sites (compile fix; 7 files)

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

