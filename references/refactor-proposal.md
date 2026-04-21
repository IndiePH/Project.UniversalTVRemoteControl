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
| R-07 | `OneRemoteApp` | `InMemoryDeviceRepository` used in production | Missing persistence | Medium | ❌ |
| R-08 | `layout_repository.dart` | `LayoutPosition` model in the application layer | Layer placement | Medium | ✅ |
| R-09 | `TvBrand`, `SsdpDeviceDiscoveryService`, `PairingPage` | No `displayName` getter — brand naming scattered | Scattered display logic | Medium | ❌ |
| R-10 | `SamsungAdapter` | Default constructor silently uses fake transport | Surprising default | Medium | ❌ |
| R-11 | `CommandDispatchResult` | No discriminated type for `unsupported` vs `failure` | Design gap | Medium | 🔶 |
| N-01 | `HisenseAdapter` | Default constructor silently uses fake transport | Surprising default | Medium | 🆕 ❌ |
| N-02 | `SamsungTransportFileLogger` | Private `_twoDigits` duplicates `formatTwoDigits` — unreachable across layers | DRY / layer placement | Low | 🆕 ❌ |

---

## Skills Used for Analysis

| Skill | Domain | What it informed |
|---|---|---|
| `refactoring` | 1-core-engineering | Primary driver — scanned for structural improvements, DRY violations, dead code, and inconsistencies without behavior change |
| `clean-code-solid` | 1-core-engineering | DRY violations: ✅ R-01 (capabilities), ✅ R-02 (formatter), 🆕 N-02 (formatter layer gap); ✅ R-08 layer placement; ✅ R-06 adapter inconsistency |
| `abstraction-domain-modeling` | 1-core-engineering | Layer placement: ✅ R-08 (`LayoutPosition`); brand ownership: ❌ R-09 (`TvBrand.displayName`), ✅ R-01 (`TvBrand.defaultCapabilities`); 🆕 N-02 (shared util layer) |
| `code-maintenance` | 1-core-engineering | Dead code: ❌ R-03 (`keyCodeFor`); ✅ R-04 (switch cases); ✅ R-05 (`firstOrNull`) |
| `technical-debt-management` | 2-architecture-system-design | Structural gaps: ❌ R-07 (missing persistence), ❌ R-10 + 🆕 N-01 (fake transport defaults), 🔶 R-11 (discriminated result type) |

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

### R-07 · `InMemoryDeviceRepository` used in production

**File:** `app/one_remote_app.dart:33`

```dart
late final InMemoryDeviceRepository _deviceRepository = InMemoryDeviceRepository();
```

Devices do not survive app restarts. Task 1.5 in `implementation_tasks.md` is still marked
partial. `SharedPrefsLayoutRepository` already shows the pattern.

**Proposed fix:** Add `SharedPrefsDeviceRepository implements DeviceRepository`, mirroring
the layout repository approach. Wire it in `OneRemoteApp`.

---

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

### R-10 · `SamsungAdapter` defaults to fake transport
### N-01 · `HisenseAdapter` defaults to fake transport *(new — same pattern)*

**Files:**
- `data/adapters/samsung_adapter.dart:20` — `transportClient ?? FakeSamsungTransportClient()`
- `data/adapters/hisense_adapter.dart:15` — `transportClient ?? FakeHisenseTransportClient()`

A developer calling `SamsungAdapter()` or `HisenseAdapter()` with no arguments silently gets
a no-op fake. `OneRemoteApp` guards this with explicit `_useFakeTransports` branching, but
the zero-arg default is a footgun for anyone instantiating these adapters in tests or new
wiring.

**Proposed fix:** Make `transportClient` required in both constructors, or rename the
zero-arg factory to `SamsungAdapter.fake()` / `HisenseAdapter.fake()` to make intent
explicit. Tests should pass `FakeSamsungTransportClient()` / `FakeHisenseTransportClient()`
explicitly. Address both adapters together.

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

## Execution Notes

- R-03 and N-02 are safe to execute independently in any order.
- R-09, N-01, and R-10 can be combined: `TvBrand.displayName` and both adapter footgun fixes
  are adjacent concerns that land cleanly in one or two commits.
- R-07 should be done before adding new device-metadata fields.
- R-11 touches a public interface; run the full test suite after.
- Execution order suggestion: N-02 → R-03 → R-09+R-10+N-01 → R-07 → R-11.
