# Reference: Device Identity and Automatic Reconnection

Consolidated from three goal docs, now removed from `references/goals/` (full history, including
rejected drafts and the conversations behind each decision, remains in git history if ever needed):
`goal-stable-device-identifier.md`, `goal-persistent-device-identity.md`,
`goal-automatic-reconnection-resilience.md`. This doc keeps only two things: how the application
actually behaves today, and why the alternatives that weren't built were rejected. It is not a
project log — no statuses, no "confirmed with user," no task numbers.

---

## Part 1: Device Identity

### The problem this solves

`TvDevice.id` used to be derived from brand + current IP address — nothing inherent to the physical
TV. A router reboot or DHCP renewal generates a different `id` for the same TV, silently orphaning
everything keyed by the old one: the saved-device entry, pairing secrets, layout/drawer state, and
the free-tier device-slot count.

### Current model

- `TvDevice.id` — **stable**, per-brand, derived from something inherent to the physical TV.
  Immutable for the life of a `TvDevice` object.
- `TvDevice.host` — **mutable**, the current LAN IPv4. Transport-only; reconciliation updates this
  field on rediscovery instead of generating a new id.

### Per-brand stable identifier sources (current)

| Brand | Source | Format | Uniqueness confidence |
|---|---|---|---|
| Roku | `serial-number` from `/query/device-info` | `roku-<serial>` | High |
| Samsung (Tizen) | UPnP SSDP `USN`/`UDN`; falls back to fetching the device descriptor XML at the SSDP `LOCATION` URL and reading `<UDN>` (and `<serialNumber>` if present) when the USN header alone doesn't yield one | `samsung-<udn>` | High |
| LG (webOS) | UPnP SSDP `USN`/`UDN` | `lg-<udn>` | High |
| Hisense (VIDAA) | SSDP `UDN`, composite `udn+model+serial` fallback, IP fallback | `hisense-<udn>` or composite | Medium — UDN reliability is firmware-dependent; worst case degrades to plain IP-based behavior, never worse than not having this at all |
| Android TV | Bluetooth MAC — see below | `androidtv-<mac>` | High |

All are unique per physical TV (not per SKU/model), and none are secret — they're observable on the
LAN and only replace the *identity* key. Pairing secrets stay in `flutter_secure_storage`, keyed by
stable id.

### Android TV's identity, specifically — three formats, in priority order

Android TV's identity converged from an initial "hash the whole pairing certificate" design into a
unified Bluetooth MAC read through two channels, with the original hash kept only as a last-resort
fallback:

1. **`androidtv-<mac>`** — the normal case. The MAC is obtained either from the device's mDNS
   `_androidtvremote2._tcp` TXT record's `bt=` field (free, connectionless, checked first), or — if
   `bt` isn't advertised — parsed from the pairing certificate's subject Common Name during a live
   TLS probe (the MAC is embedded there by the protocol itself, e.g.
   `CN=atvremote/darcy/darcy/SHIELD Android TV/XX:XX:XX:XX:XX:XX`). Both channels read the *same*
   underlying value for a given device — confirmed against `tronikos/androidtvremote2`'s reference
   implementation and Home Assistant's production integration, which treats a MAC from either
   channel as the identical `unique_id`. The cert-subject extraction algorithm is ported directly from
   that reference implementation's actual source (the MAC is the last `/`-separated segment of the
   subject's Common Name; a separate field, `dnQualifier`, carries the device name only, never the
   MAC) — with one deliberate deviation: this app validates the extracted value actually looks
   MAC-shaped before accepting it, where the reference trusts it blindly. The reference only ever
   uses the value for display; this app exact-matches saved records against it, so a malformed
   extraction needs to fail safely rather than silently produce a wrong-but-plausible-looking id.
2. **`androidtv-<sha256>`** — rare fallback. Only reached if the live cert connects but its subject
   doesn't match a recognized format (only two OEM shapes — NVIDIA Shield, Nexus Player — are
   confirmed). This is the *old* primary scheme, now demoted to fallback.
3. **`androidtv-<ip>`** — last resort. No MAC available via either channel and no live connection
   possible this scan.

The live certificate probe runs unconditionally for every discovered Android TV that doesn't already
have a MAC from `bt` this scan — it does **not** require the device to already be "recognized" as
previously paired (see rejected alternatives below).

### Why other approaches were rejected

**MAC via ARP table lookup** — more universally available than protocol-specific ids, but has
platform permission/reliability complications on Android and iOS; not pursued.

**Keep the IP-derived `id` and add a parallel `stableId` field** — rejected in favor of making `id`
itself the stable value and adding a separate mutable `host` field. The parallel-field approach keeps
a hidden dependency (transports deriving location from identity via regex over an opaque string) that
has to be kept in sync with a second field; a single `host` field removes that regex-from-`id` pattern
entirely (it existed at 8 call sites) rather than managing two identity concepts.

**Heuristic reconciliation without any stable identifier** (match by brand + model + last-known-MAC
proximity, merge on apparent re-pair) — rejected as heuristic and prone to misfiring with two similar
TVs on the same network; superseded once real per-brand stable ids were found to exist.

**Prompting the user to confirm/merge on every apparent re-pair** — least engineering effort, worst
UX; not pursued once better options existed.

**WiFi MAC as the Android TV identity anchor** — rejected. Android randomizes WiFi MACs per-network
by default since Android 10, specifically for privacy; a fixed value shown in Settings → About is
informational only, not what's actually used on the wire. The Bluetooth MAC is a different subsystem,
deliberately exposed non-randomized via both `bt` and the certificate specifically so companion apps
can persistently recognize the device.

**Serial number as the Android TV identity anchor** — investigated and ruled out. Neither the mDNS
TXT record nor the pairing certificate's subject exposes a per-unit serial over this protocol; not
retrievable via any channel this app has access to.

**Cross-confirming `bt` against the certificate before trusting a match** — originally designed to
guard against MAC-collision risk (a documented real case: Home Assistant issue #134867, two TiVo
Stream 4K units from SEI Robotics reporting the identical Bluetooth MAC). Dissolved once `bt` and the
cert-embedded MAC were confirmed to read the *same* underlying value — there is no second, independent
signal left to cross-check against. The collision risk itself doesn't go away; it's just no longer
mitigated (see below).

**Gating cert-derived id enrichment behind "is this certificate already recognized as previously
paired"** — retired. The gate was originally read as a MITM defense, but doesn't function as one:
TLS's own private-key-possession requirement already prevents an attacker from presenting an
already-known device's exact certificate without having compromised it. The actual original concern
was *consent* (a human reading a PIN on the TV and entering it), which has nothing to do with using a
MAC as a mere discovery-time label for an unpaired device — the live TLS connection already happens
unconditionally regardless of this gate; the gate only ever controlled whether the *result* was used.
(What actually distinguishes the two channels isn't "who asks first" — both `bt` and a cert read are
technically active requests — it's that `bt` is a connectionless UDP multicast query/response, no
different in kind from every other piece of mDNS discovery data and already trusted unconditionally,
while a cert read opens an actual TCP+TLS connection to the device's real remote-control port, a
targeted interaction with that specific device — which is why only the cert read ever warranted the
consent-aware caution in the first place.)

**Detecting or mitigating MAC-collision risk** — considered and explicitly not built. MAC uniqueness
is the manufacturer's responsibility (IEEE OUI allocation); a collision is their provisioning defect,
not something this app can independently re-verify without reintroducing the cross-signal check that
was just eliminated as unnecessary for the common case. Home Assistant's own production integration
has the identical exposure with no mitigation — a defect this rare going unaddressed in a mature,
widely-deployed reference implementation is itself evidence the cost doesn't justify a fix. Accepted
as a permanent, unmitigated residual risk.

**Correlating a saved `androidtv-<mac>` device against a same-scan `androidtv-<ip>` discovery** (i.e.,
reconciling through an IP change on the exact scan where neither `bt` nor a live cert connection
worked) — considered and not built. The only proposed match used the device's host as the join key,
but this scenario is defined by the host *changing* — the match could only ever fire in the case
where nothing needed updating. The only alternative that could actually fire drops the host
requirement entirely (match by count: exactly one saved candidate, exactly one discovered candidate,
anywhere on the network) — that carries real risk of merging two different physical TVs for a user
who owns more than one, with no anchor to bound it. Accepted as a self-healing gap instead: a later
scan very likely recovers the MAC and reconciles normally through the automatic retry cycle (Part 2).

**Migrating a device saved under the old `androidtv-<sha256>` scheme onto the new `androidtv-<mac>`
scheme automatically** — this one *was* built, but deliberately as a temporary, scheduled-for-removal
shim (`AndroidTvLegacySha256IdMigrator`, self-contained, gated by a single kill switch, removal
targeted ~2026-11-10 — see `references/tech-debt-list.md`), not permanent behavior. Two things kept it
from being a permanent fix: migrating trusts MAC extraction verified against only two device shapes
(a wrong extraction for some other OEM settles into a wrong-but-stable id rather than a working one),
and reaching devices that already have a `bt`-derived id requires deliberately paying for a live
connection that the normal discovery path skips for efficiency — both acceptable as a bounded,
time-boxed cost, not as a standing feature. After removal, a pre-existing old-scheme device needs one
manual re-pair, same as any device not migrated before the deadline.

### Reconciliation (current mechanism)

`DeviceReconciliationService.reconcile()` is pure and synchronous — it compares an already-discovered
list against the saved-device list, with no live network access of its own:

1. **Exact-id-match pass**: a saved device and a discovered device with the identical `id` string are
   matched; the saved device's `host` is refreshed if it changed.
2. **Legacy-rekey pass**: a saved device with no stable id yet (still IP-derived) is upgraded to a
   freshly-discovered stable id, but only when exactly one such saved device and exactly one stable
   discovery share the same host and brand (a conservative uniqueness constraint, not a live
   confirmation — there is no live confirmation step available by construction).

What this does **not** do: correlate two *different* stable-looking id strings for the same physical
device (the IP-fallback and old-scheme-migration cases above) — both are handled outside `reconcile()`
itself, or not at all, per the rejected-alternatives above.

### Migration safety properties

Re-keying a saved device from its old id onto a newly-proven stable id follows a deliberately
conservative order, designed to be lossless under interruption:

1. Layout state is copied to the new key *before* the device record itself is re-keyed.
2. The device, layout, and any credentials are written under the new stable-id key *before* the old
   record is retired — the old key is never deleted first.
3. Legacy host-keyed pairing secrets are retained as a fallback during the transition window rather
   than deleted immediately.

**Idempotent**: re-running the same migration finds the new-key entries already present and skips or
retries safely — it doesn't matter how many times a scan re-attempts it. **Interrupt-safe**: killing
the app mid-migration leaves either the old key alone (most likely) or both keys present — never
neither. If derivation or matching fails for any reason, the legacy entry is left in place and the
app keeps working off the old id until a later scan can reconcile it — data is never dropped
mid-migration.

### Data-safety / Play Store compliance notes

These constraints held when the stable-id system was designed and remain true of the current
implementation — worth checking against before touching this area again:

- **No new data leaves the device.** Every stable identifier (MAC, UDN, serial) is local-only, never
  transmitted to any server by this app. No privacy-policy or Play Data Safety form implications.
- **No encryption weakening.** Pairing secrets stay on `flutter_secure_storage` (Android Keystore
  AES-GCM) throughout; a re-key is a change to which key name a secret is stored under, on the same
  backend, never a change to how it's encrypted.
- **Backup rules unchanged.** `flutter_secure_storage` is excluded from Android auto-backup by
  default; nothing here alters `android:allowBackup`/`fullBackupContent`.
- **User-initiated deletion clears everything.** Removing a saved device clears both its legacy
  host-keyed and current stable-id-keyed entries during any transition window — deletion was designed
  to never leave an orphaned credential behind.
- **No new network calls introduced by identity capture itself** beyond what each brand's discovery
  already does (e.g. Hisense's composite-fallback descriptor-XML fetch is the same LAN traffic profile
  as Roku's existing device-info fetch).
- **Orthogonal to Play Integrity / App Check.** Stable-id capture is unrelated to and unaffected by
  server-side receipt validation (see `references/goals/goal-pro-receipt-validation-remote-setup.md`).

### Legacy orphan cleanup

A saved device whose id is still IP-derived (never migrated to a stable id) is tracked for staleness,
separately from the migration mechanism above: a discovery scan records a `lastSeenAt` timestamp
whenever exactly one discovered device matches its brand and host. A legacy record with no timestamp
yet starts a 30-day grace period from the first scan after this tracking shipped. A record unseen for
30 days is surfaced to the user for **explicit confirmation** — it is never removed automatically.
Confirmed removal unpairs the device and deletes its saved-device record and its per-device layout
key together, so no orphaned layout survives a confirmed cleanup. The currently-active device is
always excluded from this tracking, regardless of how long it's been "unseen" by discovery specifically
(it's in active use, not stale).

### Known, accepted gaps

- **Roku has no post-pairing identity re-derivation at all.** Its stable id (ECP serial number) is
  captured once at pairing; discovery never re-derives it on a later scan. A Roku that changes IP
  after pairing cannot be matched by reconciliation, regardless of how often reconciliation runs. No
  fix designed or built for this.
- **A brand-new Android TV's very first pairing is IP-keyed, not stable-id-keyed.** The certificate
  (and thus the MAC it embeds) is only reliably readable *after* a live connection succeeds — at
  first pairing, that connection is what's in progress. An IP change between discovery and first
  pairing completing orphans that attempt — an edge case, no worse than the pre-stable-id behavior
  for any brand.
- **Manually-added devices (any brand, entered by IP rather than discovered) have no passive identity
  source at all.** They stay IP-keyed until a live connection can establish a real one; nothing
  currently derives a stable id from a manual-entry flow itself.
- **MAC-collision risk is real and permanently unmitigated** (see above).
- **An Android TV whose IP changes on the exact scan neither `bt` nor a live cert connection works
  will not reconcile that scan** — self-heals on a later scan (see above).
- **A legacy (IP-keyed, never-migrated) saved device whose host changes before it's ever matched to a
  stable id cannot be re-keyed with certainty** by the generic legacy-rekey pass — it requires an
  exact host+brand match, and a moved host breaks that match the same way it does for any other
  format mismatch. The old record and its layout remain available rather than being guessed at.
- **Uncertain, not confirmed either way**: the original persistent-identity work's final validation
  step (an explicit end-to-end router-reboot integration test, plus interrupted-migration fallback
  coverage) was marked pending at the time that work shipped. `device_scoped_secret_gateway_test.dart`
  has a test scenario referencing a router-reboot case, but whether it fully satisfies what was
  originally scoped is unverified — worth checking directly before assuming either way if this area
  is touched again.

---

## Part 2: Automatic Reconnection

### The problem this solves

Neither device-connection screen retried or reconciled automatically. The remote/home page redialed
the exact same last-known host every 5 seconds forever, with no escalation and no reconciliation. The
paired-list page's reachability indicator ran one probe per manual rescan; the page's own
reconciliation pass ran on every scan but fire-and-forget, so a successful reconciliation never
triggered a re-check within the same scan. Net effect: a device that had a correct stable id could
stay disconnected for hours after a transient failure, purely because nothing retried or re-checked
while the app was open, until it was manually reopened.

### Current mechanism — remote/home page

`ReconnectionRetryController` runs a repeating cycle while the page is open and disconnected:

1. **Fast phase** — 3 connect attempts, 5 seconds apart.
2. **Escalation** — one discovery + reconciliation pass, then a single connect attempt against
   whatever the reconciliation found.
3. **Wait** — on continued failure, a wait period shown as "Connection error... retrying in Xs" with
   a live countdown and a manual retry-now option. The wait grows exponentially across successive
   failed laps (45s → 90s → 180s → 300s, capped at 5 minutes), bounding worst-case retry spacing for a
   genuinely long-absent device without giving up recovery speed early in a disconnected streak.
4. Loop back to the fast phase, indefinitely, until connected or the page closes.

Growth resets to the 45s base when a fresh disconnected streak begins (a real connection succeeded,
or the page/device resubscribed) or the user taps retry-now — a manual retry gets the fastest path
back rather than inheriting escalation from unrelated prior failures.

A device-refresh gap was found and closed during implementation: reconciliation only updates an
in-memory registry and persists the new host to the repository — it doesn't update the `TvDevice`
object the page or the retry controller is actively holding. Without an explicit fix, a successful
reconciliation right after a host change would still dial the stale IP on the next attempt. Fixed by
having the controller re-read the saved-device list after reconciliation and, if the host differs,
use the refreshed device for its own next connect and notify the page to update its active device.

### Current mechanism — paired-list page

Each paired device's reachability indicator: probe the known host → on failure, await the page's own
already-running reconciliation pass (shared across every indicator on the page, not one reconcile
call per device) → if this device's host changed, re-probe the new host once → grey only if both
attempts fail. No automatic retry beyond this single chain — the next manual rescan is the retry
trigger for this screen, matching its lower reliability bar (it only needs to show a reasonable
snapshot, not guarantee connectivity — that's the remote/home page's job once the user commits to
using a device).

### Why other approaches were rejected

**A new shared coordinator service between the two pages** — rejected. Both pages already receive
`RemoteCommandService`, `DeviceDiscoveryService`, and `DeviceRepository` from the same DI container;
the only missing piece (in-flight retry/backoff bookkeeping) is naturally bounded to each screen's own
lifecycle, not shared state.

**Background reconnection while the app is fully closed** — out of scope. Automatic reconnection only
needs to work while the app is open; no Android WorkManager/foreground-service mechanism was pursued,
avoiding the battery and OS-policy tradeoffs that come with one.

**Threading `DeviceIdentityRegistry` through page/controller constructors** — rejected in favor of
resolving it via the DI container at the point of use. The registry is not a second store of
identity — `TvDevice.id`, persisted via `DeviceRepository`, remains the single source of truth; the
registry is only a session-scoped, in-memory `host → stableId` lookup cache. Matches the existing
precedent elsewhere in the codebase for resolving this same dependency.

**Linear or single-step wait growth** — rejected in favor of exponential growth with a cap, the
standard shape for this exact problem (matches gRPC/AWS-SDK/Socket.IO-style reconnection backoff) —
both alternatives were presented and rejected as less proven for this use case.

**Always re-probing after reconciliation, even when the host didn't change** — rejected. A same-host
retry is a wasted network call; a genuine same-host flake self-corrects on the next manual rescan
anyway, matching the paired-list page's already-lower reliability bar.

### Known, accepted gaps

- **Roku's lack of post-pairing identity re-derivation** (Part 1) means Roku devices don't benefit
  from automatic reconciliation the way other brands do, regardless of how well the retry cycle
  itself works.
- **The fast-phase numbers specifically (3 attempts, 5s cadence) were proposed defaults, not
  independently validated** against this app's usage patterns — worth revisiting if they prove wrong
  in practice. The wait-growth numbers (45s base, ×2 growth, 5-minute cap) are a separate, confirmed
  decision, not open in the same way — they match the standard shape used for this exact problem
  elsewhere (gRPC/AWS-SDK/Socket.IO-style backoff), chosen deliberately over simpler
  linear/single-step alternatives that were considered and rejected.

---

## Tech debt this work surfaced (not fixed here — see `references/tech-debt-list.md` for full detail)

- **`AndroidTvLegacySha256IdMigrator`** is explicitly temporary, scheduled for removal ~2026-11-10.
- **The adapter→transport boundary drops `TvDevice.host` and re-derives it via a timing-dependent
  registry lookup** instead of passing it directly for calls that already have a full `TvDevice` in
  hand — a real bug (pairing failure for any brand-new, `bt`-advertising Android TV) was patched at
  the timing level; the proper fix (pass host directly) is a breaking interface change across every
  brand's transport client, deliberately deferred.
- Whether `AndroidTvCertSubjectMacParser`'s whole-DER-hash fallback is ever actually exercised in
  practice is unknown pending real-device coverage across more OEMs than the two confirmed shapes.

---

## File touchpoints

Domain: `tv_device.dart`, `tv_device_info.dart`.

Identity capture: `android_tv_bluetooth_mac_txt_parser.dart`, `android_tv_cert_subject_mac_parser.dart`,
`android_tv_certificate_store.dart`, `android_tv_tcp_transport_client.dart`,
`android_tv_legacy_sha256_id_migrator.dart`, `mdns_device_discovery_service.dart`,
`ssdp_device_discovery_service.dart`, `roku_ssdp_discovery_service.dart`, `ssdp_brand_inference.dart`.

Discovery orchestration: `composite_device_discovery_service.dart`, `discovery_result_merger.dart`.

Reconciliation: `device_reconciliation_service.dart`, `pairing_page_data.dart`,
`pairing_page_coordinator.dart` (stamps stable id + host on the enriched device post-pairing),
`brand_routed_remote_command_service.dart` (`preparePairing`, host registration timing).

Reconnection: `reconnection_retry_controller.dart`, `remote_home_page.dart`,
`pairing_page_sections.dart` (`_PairedTvConnectionIndicator`).

Adapters/transports (host resolution): `samsung_adapter.dart`, `lg_adapter.dart`,
`hisense_adapter.dart`, `tcl_google_tv_adapter.dart`, `tcl_legacy_tcp_transport_client.dart`,
`roku_http_transport_client.dart`, `android_tv_tcp_transport_client.dart`.

Persistence: `shared_prefs_device_repository.dart`, `shared_prefs_layout_repository.dart`,
`device_identity_registry.dart`, `android_tv_certificate_store.dart` (server cert storage),
`legacy_device_orphan_detector.dart` (30-day grace period cleanup),
`device_scoped_secret_persistence.dart` + `device_scoped_secret_gateway.dart` (current secret storage),
`legacy_host_scoped_secret_persistence.dart` / `legacy_secure_host_scoped_secret_persistence.dart`
(migration-window fallback), `samsung_pairing_token_store.dart`, `lg_pairing_key_store.dart`,
`hisense_pairing_auth_store.dart` (per-brand credential stores migrated to device-scoped keys).

DI: `remote_control_di_config.dart` (host resolver wiring, `AndroidTvCertificateStore` registration).

Tests: `legacy_device_orphan_detector_test.dart`, `shared_prefs_device_last_seen_test.dart`,
`shared_prefs_layout_repository_test.dart`, `discovery_result_merger_test.dart`,
`shared_prefs_device_repository_test.dart`, `adapter_tv_reachability_service_test.dart`,
`reconnection_retry_controller_test.dart`, `android_tv_cert_subject_mac_parser_test.dart`,
`android_tv_bluetooth_mac_txt_parser_test.dart`, `android_tv_legacy_sha256_id_migrator_test.dart`,
`brand_routed_remote_command_service_test.dart` (host-registration-timing regression coverage).
