# OneRemote — Implementation Tasks (Living Plan)

**Naming:** See `references/product_specs.md` (title block).

Living plan derived from `references/product_specs.md`—update both when scope shifts.

**Checklists:** Under **Status Tracker**, `[x]` marks work recorded as done in this plan; `[ ]` marks remaining. Lower sections (**Milestones**, **Cross-Cutting**) use `[ ]` as structured backlog lines that may still overlap the tracker—treat the **Status Tracker** as the current narrative for shipped vs in-flight work.

## Jira (project TVREMOTE)

- **TVREMOTE-1** — Workspace hygiene: stabilize repo against generated/transient noise (root `__pycache__/` ignore, `.gitignore`/`generated_plugins.cmake` verification); narrative and acceptance notes live under **Status Tracker → Completed** (`Workspace hygiene baseline`).
- **TVREMOTE-8** — Saved-device remove/last-used fallback test coverage completed (`test/widget_test.dart`); tracks `Next Up → Expand tests → saved-device remove/last-used fallback paths`.
- **TVREMOTE-36** — Per-brand TV adapters and transports (**implementation** epic; **To Do** in Jira; structured for additional OEMs later).
- **TVREMOTE-37** — Per-brand TV adapter and transport **testing** epic (Samsung / LG / Hisense lanes today; **To Do** in Jira).
- **Implementation** tasks under TVREMOTE-36 include **TVREMOTE-38**–**TVREMOTE-48** (refine adapters, text-input, physical validation, LG/Hisense pairing wiring), plus transport-abstraction **TVREMOTE-52** / **TVREMOTE-53** (**Done** in Jira — shared marker + event adoption shipped in repo). **TVREMOTE-38** — Samsung adapter refinement (**In Progress** in Jira; C1 shipped in repo — Status Tracker). **TVREMOTE-40** — Hisense adapter refinement (**In Progress** in Jira; C1 shipped in repo — Status Tracker). **TVREMOTE-48** — Hisense protocol-level pairing verification (**Done** in Jira; merged into **TVREMOTE-40**). **TVREMOTE-7** — Hisense Android SSDP re-validation (**In Progress** in Jira; physical validation **pass** on Hisense TV 2026-05-22 — `references/hisense_validation_matrix.md`; repo AC met). **TVREMOTE-14** and **TVREMOTE-18** are parented under TVREMOTE-36.
- **TVREMOTE-14** — Samsung approval variants on physical devices (**Done** in Jira; runbook + outcome table in `references/samsung_validation_matrix.md`; scenarios A–C **pass** on Samsung TV 2026-05-22; Samsung connect info in settings/debug sheets for model/firmware capture).
- **Testing** tasks under TVREMOTE-37: **TVREMOTE-49** (Samsung; **In Progress**), **TVREMOTE-50** (LG; **Done** in Jira), **TVREMOTE-51** (Hisense; **In Progress**). **TVREMOTE-13** — Samsung approval timeout/rejection + recovery regression tests (**Done** in Jira; parent **TVREMOTE-37**): `samsung_test_lane_test.dart`, `samsung_pairing_token_store_test.dart` (21 tests; 2026-05-22). Unsupported-flow test scope from former **TVREMOTE-16** is folded into those three lanes.
- **TVREMOTE-12** — Pairing success/failure path tests (**In Progress** in Jira; coordinator coverage shipped in `pairing_page_coordinator_test.dart`; parent **TVREMOTE-2**).
- Umbrella issues superseded by this split (historical, **Done** in Jira): **TVREMOTE-25**, **TVREMOTE-21**, **TVREMOTE-9**, **TVREMOTE-10**, **TVREMOTE-16**.
- **TVREMOTE-63** — Bottom banner + interstitial AdMob scaffold; UMP/ATT consent gating in app code (**Done**; production ad IDs + store-listing privacy URL still **TVREMOTE-26**).
- **TVREMOTE-66** — Pro (remove ads) IAP: multi-product catalog, entitlement service + Android receipt validation client, upgrade/settings UI, gates banner + interstitial + layout editor (**In Progress**; E2E blocked by **TVREMOTE-67**).
- **TVREMOTE-67** — Pro IAP store products + sandbox/device validation; Android server-side receipt validation callable shipped in repo (`functions/src/index.ts`); operator deploy still pending per `references/goals/goal-pro-receipt-validation-remote-setup.md` (**To Do** for E2E; parent **TVREMOTE-2**).
- **TVREMOTE-68** — In-app user feedback: settings sheet + Apps Script webhook (**Done** in Jira; parent **TVREMOTE-2**).
- **TVREMOTE-69** — Production feedback webhook token + privacy-policy disclosure (**To Do** in Jira; parent **TVREMOTE-2**).
- **TVREMOTE-26** — Legal/compliance release gate (**In Progress** in Jira): ATT/UMP + in-app privacy link scaffold landed; in-app legal WebView on mobile; Firebase Analytics/Crashlytics wired; iOS production AdMob IDs in repo; app feedback **TVREMOTE-68** Done; release ops **TVREMOTE-69** pending; live policy URL and device validation pending.
- **TVREMOTE-29** — Telemetry/diagnostics recorder + settings export (Task C1 **shipped** in repo; **Done** in Jira, 2026-05-22): `AppDiagnosticsRecorder`, discovery/command decorators, `DiagnosticsSummaryPanel` + copy report in debug settings; `app_diagnostics_recorder_test.dart` verified 2026-05-22.
- **TVREMOTE-28** — Interaction polish: press-scale + haptic on remote controls (**In Progress**).
- **TVREMOTE-41** — Samsung IME watch stream no eager `connect`; probe path explicit (**In Progress** in Jira).
- **TVREMOTE-42** — LG IME watch stream no eager `connect`; probe path explicit (**Done** in Jira, 2026-05-20).
- **TVREMOTE-19** — Multi-device save/switch/edit/remove (Task 2.3): pairing save/rename/remove + last-used persistence; remote-home `RemoteHomeDeviceSwitcherSheet` (Pro switch, free-tier lock); pairing manage path (**Done** in Jira, 2026-05-22; shipped in repo).
- **TVREMOTE-18** — Discovery brand identification + pairing routing (**In Progress** in Jira; Task 2.2 C1 shipped in repo — SSDP fingerprint module, IP-level merge with brand priority, limited/experimental support notes on discovery list).
- **TVREMOTE-20** — Layout-focused tests: `RemoteLayoutDropResolver` accept/reject/swap unit coverage, `SharedPrefsLayoutRepository` persistence, default `5x9` occupancy constraints, `RemoteLayoutEditor` reset widget test (four test files, 16 tests; **Done** in Jira, 2026-05-22).
- **TVREMOTE-70** — TCL legacy Wi-Fi variant resolution: exact transport model marker, registry catch-all, capabilities, pairing constant (**Done** in Jira; parent **TVREMOTE-36**). Physical validation still **experimental** — `references/tcl_validation_matrix.md`.
- **TVREMOTE-32** — Third-party license scan + attribution (**Done** in Jira, 2026-05-22): direct `pubspec.yaml` deps audited in `references/third_party_licenses.md`; no GPL/AGPL direct runtime deps; Settings → Legal → **Open source licenses** (`showLicensePage`). Manufacturer API ToS + Prime/Disney streaming trademarks still pending (not copyleft blockers).
- **TVREMOTE-31** — Milestone 0 / Task 0.2: CI quality baseline (`flutter_ci.yml`: format, analyze, test on PRs); `AppBuildConfig` + README build-profile/flavor gap notes; Gradle flavor placeholder comments (**Done** in Jira; parent **TVREMOTE-5**).
- **TVREMOTE-11** — Milestone 1 / Task 1.6: vertical-slice widget/integration coverage — pair→remote→command, remove-flow regressions, discovery failure/empty-rescan, returning last-used launch, command-dispatch failure (**Done** in Jira; shipped in `test/widget_test.dart`).

## Status Tracker (Current)

### Completed
- [x] Workspace hygiene baseline (`TVREMOTE-1`):
  - [x] Verified generated/transient artifacts are excluded by repo/platform `.gitignore` rules (`.dart_tool/`, `build/`, platform `Flutter/ephemeral`, plugin registrants, local gradle/IDE outputs)
  - [x] Added root `__pycache__/` ignore to prevent incidental Python cache churn
  - [x] Verified tracked generated plugin glue files remain intentional and clean (`linux/flutter/generated_plugins.cmake`, `windows/flutter/generated_plugins.cmake` show no diff)
- [x] Milestone 0 / Task 0.1:
  - [x] Established layered structure (`presentation` / `application` / `data` / `domain`)
  - [x] Added extensible brand adapter contracts and router-based dispatch
- [x] Milestone 0 / Task 0.2 (`TVREMOTE-31`):
  - [x] GitHub Actions CI: `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos`, `flutter test` on PRs to `main` / `master` / `develop` (`.github/workflows/flutter_ci.yml`; `qualify` skips when diff is only `references/`)
  - [x] Repo-wide `dart format` baseline applied so the format gate passes
  - [x] `AppBuildConfig` / `AppBuildProfile` centralize debug vs release → `AppEnvironment`; `main.dart` uses `environmentForMain()`
  - [x] README documents CI commands, intentional Gradle product-flavor gap, and `AppEnvironment.development` reservation
  - [x] `AdConsentCoordinator.isPrivacyOptionsRequired` timeout + fallback so settings sheet opens under widget tests (simulated Android / no Mobile Ads plugin)
  - [x] Widget tests: fake-transport discovery via prefs; one copy-transport sheet test skipped pending modal scroll/hit-test harness
- [x] Milestone 0 / Task 0.3:
  - [x] Added core entities and contracts:
    - [x] `TvDevice`, `TvBrand`, `RemoteCommand`, `DeviceCapability`, `ConnectionState`
    - [x] command dispatch result model and service interfaces
- [x] Milestone 1 / Task 1.3 (partial):
  - [x] Implemented remote surface with custom controls:
    - [x] power, mute, d-pad + OK, channel rocker, volume rocker
    - [x] text input field + send action
    - [x] search/keyboard layout control stays interactable when unpaired or when remote text is unavailable: same `No device selected.` toast as other keys when there is no active device; unsupported text input or IME-not-ready uses shared `_keyboardUnavailableMessage` ("Remote keyboard can't be used on this screen or with this TV.") for toast and status row, with `debugPrint` lines tagged `keyboard press:` / `keyboard send:` plus reason and `device.id`
  - [x] Added responsive sizing fixes for control cluster
  - [x] Unpaired interaction guidance pass:
    - [x] remote grid controls are visually disabled/tinted when no active TV is selected
    - [x] tapping disabled controls updates status with `Pair a TV first.` guidance
    - [x] pair/connect button receives temporary blink/highlight cue to drive pairing-first flow
- [x] Milestone 1 / Task 1.4 (partial):
  - [x] Implemented command pipeline with brand-specific routing
  - [x] Added adapter capability checks (`supportedCommands`, `supportsTextInput`)
  - [x] Added non-throwing dispatch results for UI-safe error handling
- [x] Milestone 1 / Task 1.2 (partial):
  - [x] Added pairing screen with:
    - [x] scan flow wired to local-network SSDP discovery
    - [x] manual brand + IP add
    - [x] IPv4 validation
    - [x] recent manual IP shortcuts
    - [x] saved device quick-reconnect section
    - [x] remove saved device flow (with active-device extra confirmation)
    - [x] pairing behavior per spec (successful new pair becomes active; saved devices persist until removed); top-of-page pairing banner removed from UI
  - [x] Moved pairing persistence and final success decision into pairing flow:
    - [x] pairing page now remains visible until pairing attempt finishes
    - [x] user input is blocked during pairing busy state
    - [x] page only returns after successful pairing completion
- [x] Milestone 1 / Task 1.5 (partial):
  - [x] Persist/select last used device
  - [x] Track and surface `lastSuccessfulPairingAt` metadata
  - [x] Removed seeded in-memory placeholder saved device (app now starts with no paired TV by default)
- [x] Milestone 1 / Task 1.1 (partial):
  - [x] Samsung pairing handshake reliability improvements:
    - [x] trigger TV approval popup during pairing (no first-command workaround)
    - [x] require token-authenticated Samsung session before treating pairing as successful
  - [x] Samsung WSS TLS trust-on-first-use (TOFU) hardening:
    - [x] queue fingerprints seen during TLS for `host:8002`, commit only after a successful WSS channel handshake; abandon pending data when connect/handshake fails (covers multi-cert / chain quirks and half-failed attempts)
    - [x] clear stored pins for that endpoint when starting Samsung pairing so stale pins or TV cert changes cannot block re-pairing after TLS work
  - [x] Hisense pairing UX fallback:
    - [x] if initial pair attempt fails, pairing flow now offers a 4-digit TV PIN dialog
    - [x] entered PIN is submitted through the adapter/service pairing-code path before final failure
    - [x] invalid PIN now shows a retry fallback loop; temporary accepted dev PIN is `1234` (fake + real transport paths)
- [x] Milestone 1 / Task 1.4 (partial):
  - [x] Corrected Samsung text-input command sequence:
    - [x] fixed `SendInputString` payload format
    - [x] added IME priming and explicit input-end send
  - [x] LG: discovery/manual device capabilities and `LgAdapter.supportsTextInput` aligned (no in-app text send until webOS text transport exists)
- [x] Milestone 3 / Task 3.1 (partial):
  - [x] Updated remote keyboard behavior so IME overlays remote screen instead of pushing layout upward
  - [x] Added settings-driven grid layout editor with drag/drop + swap behavior
  - [x] Added layout persistence and default-layout reset flow
  - [x] Fixed multi-cell drag anchor behavior for d-pad (grab-point independent)
  - [x] Added search-input composite layout item and updated it to `5x1` (`4x1` text + right icon action)
  - [x] Restored channel/volume rocker controls and aligned play/pause visual as compact `1x1` control (left play icon + right pause icon)
  - [x] Added directional visual padding tuning for d-pad arrows (up/down/left/right)
  - [x] Increased editable/control grid from `5x8` to `5x9`
  - [x] Lowered editable/control grid from `5x9` to `5x8` to reserve stable bottom-of-screen real estate for the banner ad overlay (no body resize on IME open)
  - [x] Updated default control coordinates for the latest baseline layout
  - [x] Layout editor: toggling edit mode no longer overwrites `_status` (status row is not shown while editing); layout reset uses a snackbar for visible confirmation
  - [x] Layout editor drag/drop resolution extracted to `RemoteLayoutDropResolver` (`remote_layout_drop_resolver.dart`) so the editor widget stays UI-focused
  - [x] Swap behavior: moving item stays at the dropped anchor cell; displaced control uses footprint-aware placement (validation footprints for dpad `3x3`, volume/channel `1x3`, others from item size) with edge-adjacent candidates ordered **toward the moving control’s original direction**, then opposite, then other adjacents; swap is rejected when no placement avoids overlap with unrelated controls
  - [x] Removed swap-result snackbars and the “copy last drag/drop log” debug button from the layout editor header
  - [x] SRP decomposition (remote + pairing presentation): `RemoteHomePage` delegates to `RemoteTextEntrySheet`, `RemoteHomeStatusPanel`, `RemoteHomeAppBarActions`, `RemoteHomeDebugSheet`, `RemoteHomeRemoteGrid`, `RemoteHomeActions`, and `RemoteKeyboardAvailability`; `PairingPage` delegates to `PairingPageCoordinator`, `PairingPageData`, `PairingPageDialogs`, `PairingPageViewState`, and `pairing_page_sections.dart` (see SRP checklist)
  - [x] SRP decomposition (Samsung real transport): `RealSamsungTransportClient` orchestrates `RealSamsungPairingTokenStore`, `RealSamsungRemoteTextSession`, `RealSamsungTransportLogging`, `RealSamsungWsHandshake`, and `samsung_transport_authorization.dart` (socket lifecycle + wire-up remain in the client; see SRP checklist)
  - [x] SRP decomposition (layout editor): `RemoteLayoutEditor` delegates grid geometry to `RemoteLayoutEditorGridGeometry`, background lines to `RemoteLayoutEditGridPainter`, cell previews to `RemoteLayoutEditorItemPreview`, and drag/drop session state to `RemoteLayoutEditorDragSession` (see SRP checklist)
  - [x] Presentation theming: remote/pairing/layout-editor widgets under `presentation/` no longer use ad-hoc `Colors.*` / hex for remote chrome; values live on `AppColors` (`remoteGlyphOnRemote`, `remotePowerFill`, `remoteActionSuccess*`, `layoutEditorDrop*`, `pairingModalBarrier`, `pairingBusyOnCard`, etc.) with dark-theme literals aligned to prior behavior
  - [x] **SRP Refactor Checklist (Tracked)** is fully complete (all items checked)
  - [x] Presentation metrics consolidation: `lib/remote_control/presentation/metrics/` now owns header height (`remote_layout_header_metrics.dart`), header/in-grid button geometry + play/pause pill ratios (`remote_layout_button_metrics.dart`), and the cross-fade duration shared by the pairing-hint switcher and status-panel blur overlay (`remote_pairing_hint_metrics.dart`); shared `RemoteHeaderIconButton` widget keeps the home-view pair button and editor reset button visually identical
  - [x] Remote home bottom banner ad integrated (free-tier monetization scaffold; production AdMob unit IDs still pending — see `references/marketing_strategy.md`):
  - [x] Free-tier interstitial ad scaffold (`InterstitialAdController`, engagement policy, Pro + consent gating; **TVREMOTE-63** / **TVREMOTE-66**)
  - [x] Ad consent bootstrap (`AdConsentCoordinator`: UMP + iOS ATT before `MobileAds.initialize()`; **TVREMOTE-26** partial)
  - [x] Settings sheet: platform store-account hints, privacy-policy link, UMP privacy-options when required, diagnostics summary + copy report, in-app feedback (category + message → webhook) (**TVREMOTE-29** / **TVREMOTE-66** / **TVREMOTE-68**)
  - [x] Telemetry/diagnostics (**TVREMOTE-29**): `AppDiagnosticsRecorder` + discovery/command decorators; `DiagnosticsSummaryPanel` + copy diagnostics report in debug settings; pairing session + unhandled-error recording; `app_diagnostics_recorder_test.dart`
  - [x] In-app user feedback (**TVREMOTE-68**): `FeedbackSubmissionSheet` from settings; `HttpFeedbackSubmissionService` POST JSON via `FeedbackConfig`; `AppPackageInfoSource` for `appVersion`; tests in `test/lib/app/feedback/` and `test/lib/app/package_info/` (see `references/feedback-collection-setup.md`, `references/compliance-and-release-requirements.md` §1.5; release token/policy **TVREMOTE-69**)
  - [x] Remote interaction polish: `RemotePressFeedback` + command haptics on grid/d-pad/rockers (**TVREMOTE-28**)
  - [x] Multi-device management (**TVREMOTE-19**): save/rename/remove on pairing; `setLastUsedDevice` on pair, saved-device tap, and switcher; `RemoteHomeDeviceSwitcherSheet` + header affordance (Pro switch, free-tier lock); `FreeTierSavedDeviceCleanup`
  - [x] Samsung/LG `watchRemoteTextInputReady` — no adapter-side `connect()`; use `probeRemoteTextInputReady` for explicit probe (**TVREMOTE-41**, **TVREMOTE-42**)
    - [x] new `lib/app/ads/` module (`AdConfig`, `BottomBannerAd`, `BottomBannerAdPlacement`) using `google_mobile_ads ^8.0.0`; env-aware unit IDs via `--dart-define=ADMOB_BANNER_ANDROID` / `ADMOB_BANNER_IOS` with Google's test IDs as fallback
    - [x] `MobileAds.initialize()` runs only on Android/iOS; non-mobile/`kIsWeb` paths skip the overlay entirely so layout/tests are unaffected
    - [x] `AndroidManifest.xml` + `Info.plist` carry **test** `GADApplicationIdentifier` / AdMob `APPLICATION_ID` plus a placeholder `SKAdNetworkItems` entry — these **must be swapped for the production AdMob app id and the full network-supplied SKAdNetwork list before release**
    - [x] Remote `AppBar` tightened (`toolbarHeight: 50`) with thin outline dividers; `RemoteHomePage.body` switched to `Stack(fit: StackFit.expand)` so `BottomBannerAdPlacement` overlays bottom-aligned without resizing the grid
- [x] Developer ergonomics:
  - [x] README "Current Runtime Modes": default **real** Samsung + Hisense transports for APK/physical-TV testing; fake transports opt-in via dart-define; host overrides documented; Samsung log tag `samsung_transport` (see README)
  - [x] Implementation plan: **Brand transport defaults** section (real-by-default policy; do not regress)
  - [x] Dart documentation convention: public types lead with `///` stating purpose/role; add brief `//` or `///` for non-obvious algorithms, protocol steps, platform behavior, and invariants (not line-by-line narration)
  - [x] Debug fake/real transport toggle now applies at runtime for pairing discovery (no app restart required), and debug sheet copy-log flow keeps sheet context visible on empty-log feedback
  - [x] Debug DI baseline uses real SSDP discovery; fake discovery is selected dynamically only when fake transport mode is enabled **and** the runtime command service is fake-enabled (prevents fake devices appearing when fake discovery is toggled but the app is still using real transports)
  - [x] Hisense transport naming normalized to `HisenseMqttTransportClient` and fake client moved under `lib/remote_control/debug/` to match cross-brand conventions
- [x] TCL legacy Wi-Fi variant resolution (`TVREMOTE-70`):
  - [x] `TclProtocolVariants.isLegacyWifi` + `legacyWifiModelMarker`; legacy TCP/fake transports stamp marker at `queryDeviceInfo`
  - [x] `DefaultVariantResolutionRegistry` — exact marker entry + TCL catch-all → `tcl_legacy_wifi`; pairing manual-add uses `TclProtocolVariants.legacyWifi`
  - [x] `TvCapabilities` — `keyCommands` + `powerControl` for `(TvBrand.tcl, TvDevice.defaultProtocolVariant)`
  - [x] Unit tests in `test/lib/remote_control/data/variant_resolution_registry_test.dart` (4 tests)
- [x] Milestone 1 / Task 1.1 — Samsung adapter refinement (`TVREMOTE-38`):
  - [x] `SamsungTransportClient.clearPairing(deviceId:)`; WebSocket implementation disconnects, clears in-memory host token, drops cached `ms.channel.connect` info, clears TLS endpoint pins for the host; fake transport mirrors. `SamsungAdapter.unpairDevice` delegates so removing a saved device re-enters TV approval on the next pair.
  - [x] `SamsungKeyMapper` back command publishes `KEY_RETURN` then `KEY_BACK` (firmware-tolerant alias order; `sendCommand` already loops all aliases).
  - [x] Test coverage: spy transports gain `clearPairing` stubs; `samsung_test_lane_test.dart` asserts adapter `unpairDevice` → transport `clearPairing` and back alias order; `samsung_key_mapper_test.dart` updated.
- [x] Milestone 2 / Task 2.1 — Hisense adapter refinement (`TVREMOTE-40`):
  - [x] Real MQTT transport forwards the TV-shown 4-digit PIN verbatim (no more hard-coded `1234`); fake transport keeps the dev shortcut so offline/lab runs still pair without a real TV. PIN-rejected recovery still flows through the existing PIN-retry pairing UI.
  - [x] `_pollConnectivity` attempts one non-overlapping `_ensureConnected` for previously authorized devices when the broker is detected down, instead of waiting for the next user action. Unauthorized devices keep the lazy-reconnect path.
  - [x] New `HisenseTransportClient.clearPairing(deviceId:)`; MQTT implementation disconnects, drops in-memory auth, cancels the poll timer, resets the device-info log gate; fake transport mirrors. `HisenseAdapter.unpairDevice` delegates, so unpairing re-enters the PIN gate on the next pair attempt.
  - [x] `HisenseAdapter.sendCommand` publishes every alias from `HisenseKeyMapper.keyCodesFor(command)` (e.g. `KEY_RETURNS` / `KEY_RETURN` / `KEY_BACK`) — firmware-variant tolerance for fire-and-forget VIDAA `sendkey`.
  - [x] Test coverage: spy transports gain `clearPairing` stubs; new assertions for adapter `unpairDevice` → transport `clearPairing` and the `back` command publishing all three aliases in order.
- [x] Milestone 1 / Task 1.1 (discovery hardening):
  - [x] Android APK SSDP: acquire Wi‑Fi **multicast lock** for the scan window (`flutter_multicast_lock`); manifest already declared `CHANGE_WIFI_MULTICAST_STATE` / `ACCESS_WIFI_STATE` / `INTERNET` — runtime lock was the missing piece for reliable multicast receive
  - [x] Hisense-oriented SSDP tuning: extra M-SEARCH `urn:schemas-upnp-org:device:MediaServer:1`, include `NT` in fingerprint probe, match `hiview` where firmware omits `hisense`/`vidaa` in headers
  - [x] Note: community Hisense MQTT docs (e.g. mqtt-hisensetv) assume **manual IP** + port `36669`; SSDP remains best-effort for VIDAA/DLNA fingerprints
- [x] Milestone 1 / Task 1.6 (`TVREMOTE-11`):
  - [x] Basic widget test coverage is in place
  - [x] Added full-loop widget pass:
    - [x] pair to newly discovered TV
    - [x] return to remote
    - [x] send command via remote control
  - [x] Added active-device remove confirmation regression coverage (`REMOVE` path)
  - [x] Added pairing flow regression updates for moved pairing persistence/flow control
  - [x] Added debug/runtime regression coverage:
    - [x] fake transport toggle keeps debug settings sheet open
    - [x] fake transport mode shows fake discovery devices in pairing list (only when runtime fake transport is active)
    - [x] copy transport logs keeps debug sheet open when no log exists
  - [x] Added pairing success/failure/retry coordinator coverage (`TVREMOTE-12`) in `test/lib/remote_control/presentation/pages/pairing_page_coordinator_test.dart`: non-PIN success persistence + manual-IP save + enriched-device fallback, non-PIN failure no-save invariants + sanitized-message + unsupported→failure, PIN retry depth (3-rejection eventual success, 5-rejection cancel, verbatim PIN forwarding, per-attempt `onPinRejected`), and `cancelPairing` delegation to `RemoteCommandService`
  - [x] Broader scenario tests and network edge-case validation:
    - [x] Discovery scan failure surfaces `pairingDiscoveryFailed` and clears loading state
    - [x] Empty discovery shows `pairingNoDevicesFound`; manual rescan recovers devices
    - [x] Returning flow: last-used TV restored on `RemoteHomePage` launch with connected stub; command send succeeds
    - [x] Command dispatch failure surfaces error status/toast without success message
- [x] Milestone 1 / Task 1.1 — Samsung approval variants on physical devices (`TVREMOTE-14`):
  - [x] Added Samsung physical validation matrix scaffold (`references/samsung_validation_matrix.md`) for model/firmware test runs (`TVREMOTE-49`)
  - [x] Added approval-variant runbook, code-under-test map, outcome table, and follow-up template (2026-05-22)
  - [x] Physical validation — scenario A first-time approval: **pass** (Samsung TV, 2026-05-22)
  - [x] Physical validation — scenario B token reuse: **pass** (Samsung TV, 2026-05-22)
  - [x] Physical validation — scenario C rejection/timeout recovery UX: **pass** (Samsung TV, 2026-05-22; unit paths in `TVREMOTE-13`)
  - [x] Samsung `ms.channel.connect` device info cached and shown in settings/debug via `queryDeviceInfo` + `TvDeviceDebugInfoPanel` (2026-05-22)
- [x] Milestone 1 / Task 1.1 — Hisense Android SSDP re-validation (`TVREMOTE-7`):
  - [x] Runbook + fallback-path decision in `references/hisense_validation_matrix.md` (manual IP + `TV_HOST_OVERRIDE`; port-`36669` sweep deferred)
  - [x] SSDP fingerprint unit tests (`ssdp_brand_inference_test.dart` — `hisense` / `vidaa` / `hiview` + `nt` probe)
  - [x] Physical validation on Hisense TV (2026-05-22): SSDP scan, manual-IP pair, PIN flow, keys, reconnect **pass** in known-good matrix
- [x] Pro monetization expansion (**TVREMOTE-66** / **TVREMOTE-67** app lane, commits `a5259be`–`ab7b395`):
  - [x] Multi-product catalog (`ProProductIds`: weekly/monthly/annual/lifetime) with localized plan labels and `ProUpgradePage` picker
  - [x] ProductId-specific purchase/restore across `ProEntitlementService` + store/fake repositories
  - [x] Android receipt validation client (`ProReceiptValidationService`) + Firebase callable `verifyProAndroidPurchase` in `functions/` (Play subscriptionsv2 + legacy fallback; reinstall token rebind)
  - [x] Settings sheet Pro status/upgrade/restore with plan or renewal details; entitlement refresh on app resume
  - [x] Tests in `pro_entitlement_service_test.dart`, `pro_receipt_validation_service_test.dart`, `pro_upgrade_page_test.dart`
- [x] Firebase Analytics + Crashlytics (commit `bf5d103`): Firebase init + fatal error hooks in `main.dart`; `AnalyticsService` DI with Pro entitlement + startup locale events
- [x] Android TV protobuf 6 compatibility (`ef8386b`): `PbList.createRepeated` → `List` in Android TV remote/pairing message types

### In Progress
- [ ] Milestone 3 / Task 3.1:
  - [ ] Continue usability polish for edit mode visual affordances and small-screen readability

### SRP Refactor Checklist (Tracked)
- [x] Extract keyboard-availability policy out of `_RemoteHomePageState` into a focused helper (`remote_keyboard_availability.dart`) and route keyboard press/send guards through it.
- [x] Split `RemoteHomePage` into page-shell + dedicated widgets/handlers for remote grid, pairing/debug actions, and text-entry sheet flow.
  - [x] Implemented via extracted components/helpers: `RemoteTextEntrySheet`, `RemoteHomeStatusPanel`, `RemoteHomeAppBarActions`, `RemoteHomeDebugSheet`, `RemoteHomeRemoteGrid`, `RemoteKeyboardAvailability`, and `RemoteHomeActions`.
- [x] Split `PairingPage` orchestration from widget rendering (scan/reconnect/manual pair handlers vs UI sections).
  - [x] Implemented via `PairingPageCoordinator`, `PairingPageData`, `PairingPageDialogs`, `PairingPageViewState`, and `pairing_page_sections.dart` (`PairingSavedDevicesSection`, `PairingDiscoveryList`, `PairingManualAddSection`, `PairingBusyOverlay`, `PairingActionButton`).
  - [x] Hisense PIN dialog UI builder is now delegated through `PairingPageDialogs.promptHisensePairingPin`.
- [x] Partition `RealSamsungTransportClient` into focused collaborators (socket/session lifecycle, pairing/token flow, IME/text protocol, transport logging).
- [x] Break `RemoteLayoutEditor` interaction/painter logic into smaller units with explicit responsibilities.

### Next Up
- [ ] Run parallel per-brand validation tracks (Samsung, LG, Hisense):
  - [ ] complete pairing verification and physical-device command validation per brand
  - [ ] confirm SSDP scan finds expected TVs on common home routers (multicast + client isolation)
- [ ] Connect pairing output to real protocol handshake/verification per non-Samsung brands
- [ ] Expand tests:
  - [x] pairing success/failure paths (`TVREMOTE-12`): coordinator unit coverage in `test/lib/remote_control/presentation/pages/pairing_page_coordinator_test.dart` for non-PIN success (persistence, manual-IP save, enriched-device fallback), non-PIN failure (no-save invariants, sanitized message, unsupported→failure), PIN retry depth (3-rejection success, 5-rejection cancel, verbatim PIN forwarding, per-attempt `onPinRejected`), and `cancelPairing` delegation
  - [x] Samsung approval timeout/rejection handling paths (`TVREMOTE-13`): service-lane failures preserve `TimeoutException` / `SamsungTransportAuthorizationException` messaging; retry-after-failure + `cancelPairing` delegation; token-store unauthorized/cancel/recovery unit tests
  - [ ] adapter capability unsupported flows
  - [x] saved-device remove/last-used fallback paths
  - [x] vertical-slice widget/integration edge cases (`TVREMOTE-11`): discovery failure, empty-rescan recovery, returning last-used launch, command failure surfacing
- [ ] Implement missing per-brand text-input transports and re-enable capability flags after validation
- [x] Add focused widget tests for (**TVREMOTE-20**; re-verified 2026-05-22):
  - [x] drag/drop swap behavior (including multi-cell items and resolver rejection vs accept paths) — `remote_layout_drop_resolver_test.dart`
  - [x] layout persistence and default reset behavior — `shared_prefs_layout_repository_test.dart`, `remote_layout_editor_widget_test.dart` (reset callback)
  - [x] `5x9` default layout occupancy constraints (no overlaps) — `remote_layout_grid_constraints_test.dart`

## Planning Notes

- Current source of truth: `references/product_specs.md`
- Delivery principle: speed to market over perfection
- Initial implementation focus:
  - Flutter app architecture (`product_specs.md` §1 for platform/release)
  - Wi-Fi control first
  - Samsung/LG/Hisense parallel compatibility tracks based on available hardware
- Scope can change as we learn from implementation and testing.
- **Target launch:** **End of May 2026**; shipping earlier is welcome if the build is ready.

## Team & work split (two people, agent-assisted)

**Shape:** Two-person team; both use AI agents (**Cursor** vs **Claude** as the primary assistant in each lane). **Brand-scoped code** reduces merge overlap (each person owns distinct adapter/transport files). **Shared surfaces** (`one_remote_app.dart`, router, `pairing_page.dart` shell, `brand_routed_remote_command_service.dart`) will still conflict sometimes—that is **expected**; coordinate with small, frequent merges or explicit handoff.

| Lane | Primary owner | Focus |
| --- | --- | --- |
| **A — Cursor** | UI / presentation + Samsung & Hisense | `lib/**/presentation/**` (remote, pairing, layout editor, shared remote widgets), app theme/shell, UX polish. **Brand code:** **Samsung** and **Hisense** — `samsung_adapter.dart`, `samsung/**`, `hisense_adapter.dart`, `hisense/**`, Hisense/Samsung pairing and command paths, Hisense-related discovery fingerprints where tied to those adapters. |
| **B — Claude** | Docs & reference artifacts + LG | `references/**` (specs, gap analysis, compliance notes, review-style writeups like the former **library** branch), changelog alignment, proposed tasks in `references/goal-oneremote-lib-review.md`. **Brand code:** **LG** only — `lg_adapter.dart`, LG webOS transport/pairing work. |

**Rules of thumb**

- Touch **only** your brand’s adapter/transport tree when changing protocol behavior; ping before editing the other person’s brand files.
- **Shared** layers (domain contracts, `TvBrand`, command dispatch): either owner may propose changes—prefer a short sync or sequential PRs to avoid silent drift.
- **Docs (B)** should not block **code (A)** on the critical path; ship doc updates as parallel PRs.
- Revisit this split if load is uneven (e.g. Samsung+Hisense + UI on **A** vs LG + docs on **B**).

## Brand transport defaults (physical TV & APK) — do not regress

**Policy:** For every brand where a **real** network transport exists in code, the **default** `OneRemoteApp` wiring must use that real implementation (`bool.fromEnvironment(..., defaultValue: false)` for fake toggles). Release and internal APK builds should **not** require extra `--dart-define` flags to talk to a real TV on the LAN.

**Rationale:** The primary validation surface is an APK on a phone hitting a physical TV. Defaulting to fake transport silently hides integration bugs.

**Concrete rules:**

- [ ] **Global fake toggle only:** Use a single flag `USE_FAKE_TRANSPORTS` (default `false`) to switch all adapters to fake transports for offline/lab work.
- [ ] **Samsung/Hisense default:** When `USE_FAKE_TRANSPORTS` is `false`, wire `SamsungAdapter` to `RealSamsungTransportClient` and `HisenseAdapter` to `RealHisenseTransportClient`.
- [ ] **LG and future brands:** When a real transport exists, follow the same global toggle behavior — do not introduce per-brand fake flags.
- [ ] **New brands / transports:** Copy this pattern: one global fake switch for test doubles; real by default for APK testing.
- [ ] **Documentation:** Keep `README.md` “Current Runtime Modes” in sync whenever transport toggles or host overrides change.

**Review trigger:** Any PR that touches `one_remote_app.dart` adapter factories or introduces a new `Fake*Transport` must confirm defaults still favor real transports for APK testing.

## Milestone 0 - Project Foundation

### Task 0.1 - Establish architecture and module boundaries
- [ ] Define app layers: presentation, domain, data, device communication.
- [ ] Create contracts for remote commands and device sessions.
- [ ] Decide state management approach and dependency wiring pattern.
- [ ] Document extension points for adding new TV protocols.

### Task 0.2 - Setup environment and quality baseline
- [x] Confirm Flutter project settings and lint/test configuration (`analysis_options.yaml` → `flutter_lints`).
- [x] Add CI checks for format, analyze, and tests (`.github/workflows/flutter_ci.yml`).
- [x] Add app flavor/config placeholders for debug and release (`AppBuildConfig`; README + Gradle comments; no Gradle `productFlavors` yet).

### Task 0.3 - Define shared domain models
- [ ] Create core entities:
  - [ ] TV device
  - [ ] Device capability
  - [ ] Remote command
  - [ ] Connection state
  - [ ] Saved device profile
- [ ] Define serialization contracts for local persistence.

## Milestone 1 - Vertical Slice (Samsung + LG + Hisense)

### Task 1.1 - Implement Samsung/LG/Hisense discovery
- [ ] Build local network discovery flow for Samsung, LG, and Hisense targets.
- [ ] Show discovery results with loading, empty, and error states.
- [ ] Add retry behavior and timeout handling.

### Task 1.2 - Implement manual pairing flow
- [ ] Build device selection and pairing screen flow.
- [ ] Validate and persist successful pairing credentials.
- [ ] Add user-facing error states for failed pairing attempts.

### Task 1.3 - Build minimal remote control surface
- [ ] Implement controls:
  - [ ] Power
  - [ ] Volume up/down
  - [ ] D-pad + OK
  - [ ] Back/Home
  - [ ] Text input keyboard for search/forms
- [ ] Wire controls to Android TV command adapter.
- [ ] Wire controls to Samsung/LG/Hisense command adapters.
- [ ] Provide immediate press feedback (visual + optional haptic hook).

### Task 1.4 - Build command execution pipeline
- [ ] Create unified `sendCommand(deviceId, command)` service.
- [ ] Add command result mapping (success, timeout, unavailable).
- [ ] Add support for text input command payloads for compatible protocols.
- [ ] Add lightweight logging hooks for command failures.

### Task 1.5 - Persist and restore one saved device
- [ ] Save paired device locally.
- [ ] Auto-reconnect to last used device on app relaunch.
- [ ] Handle stale/invalid session recovery paths.

### Task 1.6 - Validate end-to-end vertical slice
- [ ] Verify first-time flow:
  - [ ] discover -> pair -> remote control -> save device
- [ ] Verify returning flow:
  - [ ] app launch -> auto-connect -> immediate remote use
- [ ] Add integration/widget tests for critical paths.

## Milestone 2 - Expansion (Multi-device + compatibility hardening)

### Task 2.1 - Add/validate per-brand protocol adapters
- [ ] Implement/refine Samsung, LG, and Hisense connection and command transports where gaps remain.
- [ ] Map shared command set to brand-specific commands where supported.
- [ ] Add protocol-specific error handling and reconnection behavior.

### Task 2.2 - Upgrade discovery and device type identification
- [x] Distinguish supported device brands in discovery results (`ssdp_brand_inference.dart`, Roku SSDP hint; `DiscoveryResultMerger` prefers Samsung/LG/Hisense over Android TV/Roku for the same IP; list sorted full → limited → experimental).
- [x] Route pairing flow to the correct protocol adapter (unchanged `BrandRoutedRemoteCommandService` `(brand, protocolVariant)` routing; discovery merge avoids duplicate IPs with conflicting brands).
- [x] Add explicit "limited support" messaging for partially supported models/protocols (`DiscoveredDeviceSupport` tiers + pairing discovery subtitles for Hisense/Roku/experimental brands).

### Task 2.3 - Implement multi-device management
- [x] Save multiple TVs (pairing persistence + saved-device list).
- [x] Add device switcher and last-used device tracking (remote-home switcher sheet; `setLastUsedDevice` on switch paths).
- [x] Add edit/remove device operations (pairing screen rename + swipe-to-remove with active-device confirmation).

### Task 2.4 - Improve connection resilience
- [ ] Add reconnect backoff strategy for temporary network failures.
- [ ] Surface clear UI states: connecting, connected, disconnected, retrying.

## Milestone 3 - UX Polish and Product Readiness

### Task 3.1 - Refine remote UI for fast usage
- [ ] Improve button sizing and thumb reach.
- [ ] Optimize layout for one-hand interaction.
- [ ] Ensure dark mode is consistent and legible.

### Task 3.2 - Add interaction polish
- [ ] Add animations for key interactions.
- [ ] Add haptic feedback per command category where appropriate.
- [ ] Keep perceived latency low with responsive button states.

### Task 3.3 - Improve onboarding and fallback guidance
- [x] Add clear permission and network guidance.
- [x] Add "cannot find TV" troubleshooting path.
- [ ] Add protocol-specific help text for pairing issues.

## Cross-Cutting Tasks (Do in parallel)

### Task C1 - Telemetry and diagnostics (**TVREMOTE-29** shipped in repo)
- [x] Track discovery success/failure rates (`AppDiagnosticsRecorder` + discovery decorator; debug settings summary).
- [x] Track pairing and command error categories (pairing session + dispatch outcome counters by brand/outcome).
- [x] Add internal debug view/log export for troubleshooting (settings debug section: `DiagnosticsSummaryPanel`, copy diagnostics report; existing transport log copy retained).

### Task C2 - Testing strategy
- [ ] Unit tests for domain and command routing.
- [ ] Widget tests for onboarding/pairing/remote states.
- [ ] Integration tests for connect/send command/reconnect paths.

### Task C3 - Platform considerations
- [ ] Android:
  - [ ] LAN discovery: multicast lock + manifest multicast-related permissions for dependable SSDP (Task 1.1)
  - [ ] optional IR behind feature flag
- [ ] iOS:
  - [ ] Wi‑Fi / local network permissions and entitlements per Apple requirements
  - [ ] **Compatible** with `product_specs.md` §1; **release** timing may differ from Android

### Task C4 - Backlog candidates (Post-MVP)
- [ ] IR mode and brand signal testing flow.
- [ ] Voice control integration.
- [ ] Automation routines (watch mode, schedule).
- [ ] Cloud remote access and account sync.
- [ ] Widgets/lockscreen/wearable support.
- [ ] Broader brand expansion beyond Samsung/LG/Hisense.

## Suggested Execution Order (Now)

- [ ] Task 0.1 -> 0.3 (foundation and contracts)
- [ ] Task 1.1 -> 1.5 (vertical slice implementation)
- [ ] Task 1.6 (end-to-end validation)
- [ ] Task 2.1 -> 2.4 (second brand + resilience)
- [ ] Task 3.1 -> 3.3 (polish and usability hardening)

## Definition of Done (Current)

- [ ] User can discover, pair, and control Samsung/LG/Hisense TVs reliably on **Android** (current validation focus).
- [ ] Text input from the app keyboard to Samsung TVs where the WebSocket IME path works on the model.
- [ ] Per-brand text transport/capability flags only after implementation + validation on physical TVs.
- [ ] Relaunch → quick control of last TV; multi-device save/switch; shared command set across brands.
- [ ] Core flows covered by automated tests; CI green.
- [ ] **iOS:** extend the same acceptance criteria when an iOS store release is in scope (parity with §1).

## Final Release Gate (Legal & Compliance)

- [x] Run a legal/license pass for any adopted external protocol references or copied logic before release (**TVREMOTE-32**, 2026-05-22 — `references/third_party_licenses.md` protocol + dependency audit).
- [x] Confirm third-party notices/attributions and license text obligations are satisfied in-app/repository (**TVREMOTE-32** — Settings → Legal → Open source licenses; tracker doc updated).
- [x] Record final go/no-go license status in `references/third_party_licenses.md` (**TVREMOTE-32** — OSS **Go**; manufacturer ToS + streaming trademarks conditional).
- [x] No unresolved **copyleft** obligations in direct runtime dependencies (**TVREMOTE-32**); manufacturer API ToS and brand marks remain separate gates (**TVREMOTE-26** / compliance §2.1).
- [ ] **Store submission blockers** (expanded checklist: `references/compliance-and-release-requirements.md`):
  - [ ] Privacy policy at a live public URL; linked in App Store Connect and Play Console (in-app link scaffold only until URL is live).
  - [x] iOS: App Tracking Transparency integrated in app code; prompt before first ad SDK init (`AdConsentCoordinator`).
  - [x] EU/California: UMP consent integrated in app code before ad load; device/regional validation still required.
  - [x] Pro: IAP via Apple IAP + Google Play Billing only (`in_app_purchase`) supporting multi-product subscriptions + lifetime (`ProProductIds` catalog); override via `--dart-define=PRO_PRODUCT_ID=...` (see `lib/app/configurations/app_monetization_di_config.dart`); Android server-side receipt validation callable in repo (`functions/src/index.ts` — deploy per `references/goals/goal-pro-receipt-validation-remote-setup.md`).
  - [ ] Developer accounts and signing: Apple Developer Program, Google Play developer account, AdMob as needed before ads go live.
  - [ ] Swap **placeholder AdMob ids** for production: replace test `APPLICATION_ID` in `android/app/src/main/AndroidManifest.xml`, test `GADApplicationIdentifier` in `ios/Runner/Info.plist`, and the placeholder `SKAdNetworkItems` array (currently `cstr6suwn9.skadnetwork` only) with the full Apple-required SKAdNetwork list; provide production unit IDs via `--dart-define=ADMOB_BANNER_ANDROID` / `ADMOB_BANNER_IOS` / `ADMOB_INTERSTITIAL_ANDROID` / `ADMOB_INTERSTITIAL_IOS` for release builds.
- [ ] **Physical-device validation:** Do not claim store support for a brand until pairing and core commands are verified on at least one real TV of that brand (complements the brand readiness matrix in `references/product_specs.md`).
- [ ] **Deferred code-quality/security follow-ups** from the April 2026 lib review (no code until individually confirmed): `references/goal-oneremote-lib-review.md`.

## Change Control Notes

- This is a living implementation plan, not a fixed contract.
- Any major scope change should update:
  - milestone priority
  - acceptance expectations
  - test coverage targets
- Prefer incremental delivery with working slices over broad unfinished features.
