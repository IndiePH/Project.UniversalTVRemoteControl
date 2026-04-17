# Third-Party Licenses Tracker

This document tracks third-party libraries considered for TV brand integrations and their commercial-use license status.

## Current Decision

- No third-party runtime dependencies are currently used for TV control.
- TV control implementation is currently internal-only (adapter architecture in project code).
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

- No third-party TV-control library is currently integrated into `pubspec.yaml`.
- Current brand routing is internal adapter architecture with local stubs:
  - `SamsungAdapter`
  - `LgAdapter`
  - `HisenseAdapter`
- Add a dependency entry to this tracker before introducing any new external package.

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
| 2026-04-17 | AI Agent + User decision | N/A | N/A | N/A | Defer external libraries | No-Go (deferred) | Removed prior Samsung/LG/Hisense candidate entries; continue with internal adapters only |
