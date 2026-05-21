# Third-Party Licenses Tracker

This document tracks third-party libraries considered for TV brand integrations and their commercial-use license status.

## Manufacturer API terms (TV OEMs)

Smart TV control uses each vendor’s APIs or protocols. **Commercial shipping** should include a recorded review of the current developer terms for each integrated manufacturer (Samsung SmartThings / Tizen paths, LG webOS / ThinQ, Hisense VIDAA, etc.). This is separate from open-source **library** licenses: it is about API registration, allowed use, and revocation risk. Summarize decisions and links here or in `references/compliance-and-release-requirements.md` §2.1 before claiming production readiness.

## Current Decision

- **`mqtt_client`** (pub.dev, MIT): used for **Hisense VIDAA** local MQTT (`RealHisenseTransportClient`). Preserve upstream copyright notice per MIT when shipping.
- **`flutter_multicast_lock`** (pub.dev, MIT): used on **Android** during SSDP discovery to acquire `WifiManager.MulticastLock` for the scan. Preserve upstream copyright notice per MIT when shipping.
- **`crypto`** (pub.dev, BSD-3-Clause): SHA-256 fingerprints for Samsung WSS trust-on-first-use (`SamsungTlsTrustStore`). Preserve upstream copyright notice when shipping.
- **`flutter_svg`** (pub.dev, MIT): renders streaming shortcut brand SVGs in the remote grid.
- **Simple Icons** (CC0 1.0): Netflix SVG mark under `assets/icons/streaming/` (from [simple-icons/simple-icons](https://github.com/simple-icons/simple-icons) v12.4.0). Preserve upstream license notice when shipping.
- **Prime Video** wordmark: `assets/icons/streaming/prime_video.svg` (custom export; not from Simple Icons). Confirm trademark/brand usage complies with your distribution policy.
- **Disney+ logo SVG** (Wikimedia Commons): `assets/icons/streaming/disney_plus.svg` — trademark of Disney; used to identify the Disney+ app shortcut. Review brand/trademark guidelines before commercial release.
- Samsung / LG transports remain project-owned code paths (no third-party TV protocol SDK beyond `mqtt_client` for Hisense).
- This tracker is retained for future evaluations and release audit traceability.

## Policy Notes

- Do not integrate a library unless its license is explicitly identified and reviewed.
- For MIT/BSD/Apache-2.0 libraries, preserve copyright and license notices.
- Re-check license files before release in case upstream terms change.
- If a dependency uses copyleft licensing (GPL/AGPL), perform explicit legal review before use.
- Some candidate repositories are relatively old/low-activity. Treat them as "use with caution":
  - validate maintenance state, open issues, and protocol drift risk before production adoption
  - prefer pinning vetted commits and wrapping integrations behind internal adapters

## Candidate Libraries

No external TV-control libraries are currently approved for integration.
This project currently relies on internal adapter implementations.

## Current Project State

- `pubspec.yaml` includes **`mqtt_client`** for Hisense MQTT, **`flutter_multicast_lock`** for Android SSDP discovery, and **`crypto`** for Samsung TLS TOFU fingerprints, as above.
- Brand routing remains internal adapter architecture:
  - `SamsungAdapter` (WebSocket)
  - `LgAdapter` (stub / future webOS)
  - `HisenseAdapter` (MQTT over `mqtt_client`)
- Add a dependency entry to this tracker before introducing any additional external TV-control packages.

## Release Checklist (Licenses)

- Confirm dependency versions and license files at the pinned commit/version.
- Add attribution/license text to release artifacts (as required by each license).
- Record verification date and reviewer in this file before production release.

## Go / No-Go Criteria

Before adopting a third-party library in production, all of the following should be true:

1. **License check (required)**:
   - License file is present in the upstream repository at pinned commit/version.
   - License is compatible with commercial distribution policy.
2. **Maintenance check (required)**:
   - No unresolved blockers found in critical issue reports affecting core usage path.
   - Dependency does not require unsupported platform/runtime versions.
3. **Technical smoke test (required)**:
   - Can connect/pair on at least one physical target TV for the brand.
   - Can send core commands (`power`, navigation, volume) successfully.
   - Text input path is validated if feature is claimed as supported.
4. **Integration hygiene (required)**:
   - Wrapped behind internal adapter interface (no direct UI coupling).
   - Commit/version pin recorded in this document.
   - Attribution/notice artifact prepared for release.

## Verification Log

| Date | Reviewer | Library | Version/Commit Checked | License Verified | Commercial Use Decision | Go/No-Go | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-04-17 | Maintainer + stakeholder | N/A | N/A | N/A | Defer external libraries | No-Go (deferred) | Removed prior Samsung/LG/Hisense candidate entries; continue with internal adapters only |
| 2026-04-18 | Maintainer | flutter_multicast_lock | pub.dev (MIT) | MIT | OK for use (MIT) | Go (runtime dep) | Android SSDP discovery only; not a TV protocol SDK |
