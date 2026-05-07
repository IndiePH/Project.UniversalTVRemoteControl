# Test Updates Needed

Two batches of deferred test work. Both batches need to be done before running the test suite — the rename batch will cause compile failures; the behavioural batch fills coverage gaps.

---

## Batch 1 — `fourDigitPin` → `pinCode` rename (compile failures)

All test mocks implementing `TvBrandAdapter.submitPairingCode` or `RemoteCommandService.submitPairingCode` need their parameter renamed from `fourDigitPin:` to `pinCode:`. Call sites that pass `fourDigitPin: '...'` need the same rename.

### `test/lib/remote_control/data/adapters/hisense_test_lane_test.dart`
- **Mock implementations** (lines 247, 291): `required String fourDigitPin` → `required String pinCode`
- **Mock body** (line 249): `submittedPins.add(fourDigitPin)` → `submittedPins.add(pinCode)`
- **Call sites** (lines 169, 186, 201): `fourDigitPin: '5678'` → `pinCode: '5678'`

### `test/lib/remote_control/data/adapters/lg_test_lane_test.dart`
- **Mock implementation** (lines 306–308): `required String fourDigitPin` → `required String pinCode`
- **Call site** (line 198): `fourDigitPin: '1234'` → `pinCode: '1234'`

### `test/lib/remote_control/data/adapters/samsung_test_lane_test.dart`
- **Two mock implementations** (lines 280–282, 338–340): `required String fourDigitPin` → `required String pinCode`
- **Call site** (line 155): `fourDigitPin: '1234'` → `pinCode: '1234'`

### `test/lib/remote_control/data/adapter_tv_reachability_service_test.dart`
- **Mock implementation** (lines 132–134): `required String fourDigitPin` → `required String pinCode`

### `test/lib/remote_control/data/brand_routed_remote_command_service_test.dart`
- **Two mock implementations** (lines 681–685, 745–747): `required String fourDigitPin` → `required String pinCode`
- **Call sites** (lines 190, 203, 215, 481, 495, 505, 507): `fourDigitPin: '1234'` → `pinCode: '1234'`

### `test/lib/remote_control/presentation/pages/pairing_page_coordinator_test.dart`
- **Mock implementation** (lines 231–233): `required String fourDigitPin` → `required String pinCode`
- **`promptPin` lambdas** (lines 42, 57, 78, 99, 122, 140, 168, 184): all use `(_) async =>` — must become `(_, __) async =>` to match the new `Function(String, PinFormat)` signature

### `test/lib/remote_control/presentation/pages/pairing_page_test.dart`
- **Two mock implementations** (lines 561–563, 611–613): `required String fourDigitPin` → `required String pinCode`

---

## Batch 2 — Deferred task #8: `pinRequired` / `PinFormat` behavioural coverage

### `test/lib/remote_control/application/command_dispatch_result_test.dart`
Add a new `group('CommandDispatchResult.pinRequired', ...)` covering:
- `isPinRequired` is `true`
- `isSuccess` is `false`
- `pinFormat` defaults to `PinFormat.fourDigitNumeric` when not specified
- `pinFormat` is `PinFormat.sixCharHex` when explicitly passed
- `message` is preserved

### `test/lib/remote_control/data/brand_routed_remote_command_service_test.dart`
In the existing `preparePairing enrichment` group, add assertions for `pinFormat` on `pinRequired` results:
- Hisense path (adapter throws `PinRequiredException`): `result.pinFormat == PinFormat.fourDigitNumeric`
- Android TV path (capability `pinPairing` set): `result.pinFormat == PinFormat.sixCharHex`

Also add a dedicated `group('preparePairing — pinPairing capability + pinFormat', ...)`:
- `pinRequired` result carries `pinFormat` derived from `TvCapabilities.pinFormatFor`
- Verify `TvBrand.androidTv` → `PinFormat.sixCharHex`
- Verify `TvBrand.hisense` → `PinFormat.fourDigitNumeric`

### `test/lib/remote_control/presentation/pages/pairing_page_coordinator_test.dart`
All `preparePairingResult: CommandDispatchResult.failure('Needs PIN')` stubs (lines 36, 52, 69, 93, 112, 161, 178) should be changed to `CommandDispatchResult.pinRequired('Needs PIN')` — the coordinator checks `isPinRequired`, not `isSuccess`, to enter the PIN flow.

Add new tests:
- `promptPin` is called with the `PinFormat` from the result (verify the second argument)
- `PinFormat.sixCharHex` is forwarded to `promptPin` when result carries it
- Cancelling the `promptPin` dialog (returning `null`) results in `PairingAttemptResult.failure`

### `test/lib/remote_control/presentation/pages/pairing_page_test.dart`
- Line 513: `CommandDispatchResult.failure('Needs PIN')` → `CommandDispatchResult.pinRequired('Needs PIN')`
- Add a widget test verifying the PIN dialog renders correctly when `pinFormat` is `PinFormat.sixCharHex` (label shows "6-character code", max length 6, keyboard is `visiblePassword`)
