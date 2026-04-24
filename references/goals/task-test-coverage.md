# Task 2.2 — Test Coverage Breakdown

Sub-tasks for goal `app-refactor-ui` task 2.2: write unit tests covering current behaviour
in all areas flagged by 2.1. Each task below is a single test file to create or expand.
Complete all before beginning any refactor task (2.3+).

**Test conventions (from existing tests):**
- No mocking frameworks — concrete fake/spy classes defined at bottom of file
- File path mirrors source path under `test/lib/`
- Group related tests with `group()`, `setUp()` for SharedPreferences mocks
- Descriptions: `'ClassName: what it does'` for units, `'Brand lane: what it does'` for lanes

---

## New Files

| ID | Test file | Pins behaviour for | Ref | Status |
|----|-----------|--------------------|-----|--------|
| T-01 | `test/lib/remote_control/data/adapters/samsung/samsung_key_mapper_test.dart` | Full command→key-code mapping; `keyCodeFor` ≡ `primaryKeyCodeFor` for all commands | R-03 (2.7) | pending |
| T-02 | `test/lib/remote_control/data/adapters/hisense/hisense_key_mapper_test.dart` | Full command→key-name mapping; app-launch commands return empty (handled via `launchVidaaApp`) | — (gap) | pending |
| T-03 | `test/lib/remote_control/data/adapters/hisense_test_lane_test.dart` | `HisenseAdapter` + `BrandRoutedRemoteCommandService` (Hisense lane): no-arg constructor uses `FakeHisenseTransportClient`; `preparePairing` calls connect; `sendCommand` routes key commands and app launches; `sendText` throws `UnsupportedError`; `submitPairingCode` forwards pin; `unpairDevice` is a no-op | N-01 (2.8), N-06 (2.3) | pending |
| T-04 | `test/lib/remote_control/application/command_dispatch_result_test.dart` | All 4 constructors; `success` → `isSuccess=true, isCompatibilityIssue=false`; `unsupported` and `failure` both → `isSuccess=false, isCompatibilityIssue=false` (current ambiguity to be fixed by R-11); `compatibility` → `isSuccess=false, isCompatibilityIssue=true` | R-11 (2.13) | pending |
| T-05 | `test/lib/remote_control/presentation/formatting/two_digit_format_test.dart` | `formatTwoDigits`: single-digit padded to 2 chars; double-digit unchanged; zero padded; value ≥ 10 not padded | N-02 (2.5) | pending |

---

## Existing Files — Expand

| ID | Test file | Add coverage for | Ref | Status |
|----|-----------|-----------------|-----|--------|
| T-06 | `test/lib/remote_control/data/adapters/lg_test_lane_test.dart` | `submitPairingCode` success + error; `unpairDevice` completes without error; `BrandRoutedRemoteCommandService.watchRemoteTextInputReady` (LG: returns adapter stream; no-adapter → false; capability gate → false) | N-06 (2.3) | pending |
| T-07 | `test/samsung_test_lane_test.dart` → relocate to `test/lib/remote_control/data/adapters/samsung_test_lane_test.dart` | Move file to mirror lib/ structure; add: `preparePairing` success; `submitPairingCode` success + error; `unpairDevice` is a no-op; `watchRemoteTextInputReady` (no textInput capability → false) | N-06 (2.3) | pending |

---

## Out of scope for 2.2

| File | Reason |
|------|--------|
| `SharedPrefsDeviceRepository` | Not flagged in 2.1; not touched in Branch 2 refactors |
| `SharedPrefsLayoutRepository` | Same as above |
| `TvDevice.fromJson/toJson` | Not flagged; not touched in Branch 2 |
| `LgWebSocketTransportClient` toggle state (N-03, N-04) | Requires real WebSocket; observable behaviour already pinned by `lg_test_lane_test.dart` via `FakeLgTransportClient` |
| `SamsungWebSocketTransportClient` connect methods (N-08) | Private methods; not directly unit-testable |
| `BrandRoutedRemoteCommandService` no-adapter path | Low-value edge case; routing already covered by lane tests |
| `SamsungTransportFileLogger._twoDigits` | Private; T-05 covers the canonical `formatTwoDigits` that will replace it |
