# Third-Party Licenses Tracker

Tracks **open-source dependencies**, **bundled assets**, and **protocol/reference** posture for OneRemote. Manufacturer API terms of service are a separate gate (see [Manufacturer API terms](#manufacturer-api-terms-tv-oems)).

## Release go / no-go (2026-05-22, TVREMOTE-32)

| Area | Decision | Blocker for OSS / attribution scope? |
| --- | --- | --- |
| Direct `pubspec.yaml` runtime dependencies | **Go** — all permissive (MIT, BSD-3-Clause, Apache-2.0); no GPL/AGPL in direct runtime deps | No |
| Transitive OSS (full tree) | **Go** — standard Flutter/pub stack; no copyleft flagged in direct-path review; re-run before each release tag | No (re-verify at release) |
| In-app OSS notices | **Go** — Settings → Legal → **Open source licenses** uses Flutter `showLicensePage` (aggregates `LICENSE` from resolved packages) | No |
| TV protocol / adapter code | **Go** — internal implementations; no third-party TV-control SDK vendored into `lib/` | No |
| Streaming shortcut assets (SVG) | **Conditional** — CC0 Netflix mark OK; Prime Video / Disney+ wordmarks need trademark/brand review before store claims | Yes (brand/trademark, not copyleft) |
| Manufacturer API ToS (Samsung / LG / Hisense / …) | **Pending** — human review of current developer terms not recorded here yet | Yes (commercial/API risk; tracked with **TVREMOTE-26**) |

**Summary:** No unresolved **copyleft** or **OSS attribution** blockers for the intended release dependency set. Release still requires manufacturer ToS sign-off and streaming-brand review per table above.

## Direct runtime dependencies (`pubspec.yaml`)

Verified against pinned versions in `pubspec.lock` / pub cache `LICENSE` files on **2026-05-22**.

| Package | Pinned (lock) | License | Role in app |
| --- | --- | --- | --- |
| `mqtt_client` | 10.11.11 | MIT | Hisense VIDAA MQTT transport |
| `flutter_multicast_lock` | 1.2.0 | MIT | Android SSDP multicast lock |
| `crypto` | 3.0.7 | BSD-3-Clause | Samsung WSS TOFU fingerprints |
| `flutter_svg` | 2.3.0 | MIT | Streaming shortcut SVG rendering |
| `get_it` | 9.2.1 | MIT | DI |
| `unity_levelplay_mediation` | 9.2.0 | Unity Advertising Terms of Service | Banner ads (LevelPlay) |
| `in_app_purchase` | 3.2.3 | BSD-3-Clause | Pro (remove ads) IAP |
| `shared_preferences` | 2.5.5 | BSD-3-Clause | Persistence (devices, layout, TLS pins, …) |
| `path_provider` | 2.1.5 | BSD-3-Clause | App documents paths |
| `multicast_dns` | 0.3.3 | BSD-3-Clause | mDNS discovery helpers |
| `protobuf` | 3.1.0 | BSD-3-Clause | Protocol buffers (where used) |
| `basic_utils` | 5.8.2 | MIT | Crypto/cert utilities |
| `pointycastle` | 4.0.0 | MIT (Bouncy Castle) | Crypto primitives |
| `http` | 1.6.0 | BSD-3-Clause | HTTP client |
| `url_launcher` | 6.3.2 | BSD-3-Clause | Privacy policy / external links |
| `package_info_plus` | 8.3.1 | BSD-3-Clause | App version label |
| `intl` | 0.20.2 | BSD-3-Clause | Localization |
| `cupertino_icons` | 1.0.9 | MIT | iOS-style icons |
| `flutter` / `flutter_localizations` | SDK | BSD-3-Clause | Framework |

**Dev-only** (not shipped in release APK/IPA artifact from app code): `flutter_test`, `flutter_lints`, `flutter_launcher_icons`.

**Copyleft scan:** No GPL/AGPL **direct** runtime dependencies. Policy: do not add copyleft TV/protocol packages without explicit legal review (see [Policy notes](#policy-notes)).

## Bundled assets (non-pub)

| Asset | Source | License / rights | Notes |
| --- | --- | --- | --- |
| `assets/icons/streaming/netflix.svg` | [simple-icons/simple-icons](https://github.com/simple-icons/simple-icons) v12.4.0 | CC0 1.0 | Preserve upstream notice in release materials if required by your process |
| `assets/icons/streaming/prime_video.svg` | Custom export | Trademark / brand | Confirm Amazon Prime Video brand usage before commercial store listing |
| `assets/icons/streaming/disney_plus.svg` | Wikimedia Commons derivative | Disney trademark | Review Disney brand guidelines before commercial release |
| `assets/icons/app_icon.png` | Project | Project-owned | — |

## Protocol and reference audit (2026-05-22)

| Integration | Implementation | External code copied? |
| --- | --- | --- |
| Samsung TV | `SamsungAdapter` + WebSocket client in `lib/remote_control/data/adapters/samsung/` | No — project-owned; public protocol behavior only |
| LG TV | `LgAdapter` (webOS path) | No — internal stub/adapter |
| Hisense TV | `HisenseAdapter` + `mqtt_client` | No TV SDK — MQTT client is OSS dep above |
| Android TV / Roku / TCL | Brand adapters under `lib/remote_control/data/adapters/` | No third-party TV SDK |
| Discovery | SSDP + mDNS + `flutter_multicast_lock` | No vendored discovery library |

No external TV-control **candidate libraries** are approved for integration (internal adapters only).

## Manufacturer API terms (TV OEMs)

Smart TV control uses each vendor’s APIs or protocols. **Commercial shipping** should include a recorded review of the current developer terms for each integrated manufacturer (Samsung SmartThings / Tizen paths, LG webOS / ThinQ, Hisense VIDAA, etc.). This is separate from open-source **library** licenses: it is about API registration, allowed use, and revocation risk.

| OEM | Review recorded | Status |
| --- | --- | --- |
| Samsung | No | Pending — see `references/compliance-and-release-requirements.md` §2.1 |
| LG | No | Pending |
| Hisense | No | Pending |

## In-app and repository notices

- **In-app:** Remote home → Settings → **Legal** → **Open source licenses** → Flutter license page (all resolved package licenses).
- **Repository:** This file + `pubspec.lock`; optional export: build release then use platform store “licenses” or Flutter tooling as needed for store submissions.

## Policy notes

- Do not integrate a library unless its license is explicitly identified and reviewed.
- For MIT/BSD/Apache-2.0 libraries, preserve copyright and license notices (in-app page + release process as required).
- Re-check license files before each release tag in case upstream terms change.
- If a dependency uses copyleft licensing (GPL/AGPL), perform explicit legal review before use.
- Prefer pinning versions and wrapping integrations behind internal adapters.

## Candidate libraries

No external TV-control libraries are currently approved for integration. Brand routing uses internal adapter architecture.

## Release checklist (licenses)

- [x] Direct dependency versions and SPDX-style licenses recorded in this file (2026-05-22).
- [x] In-app OSS license viewer wired (`showLicensePage`).
- [ ] Re-run dependency + asset review immediately before store submission tag.
- [ ] Manufacturer API ToS outcomes recorded (§2.1 compliance doc).
- [ ] Streaming brand/trademark sign-off for Prime Video and Disney+ shortcuts.

## Verification log

| Date | Reviewer | Scope | License verified | Commercial OSS decision | Go/No-Go | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-04-17 | Maintainer + stakeholder | External TV libs | N/A | Defer third-party TV SDKs | No-Go (deferred) | Internal adapters only |
| 2026-04-18 | Maintainer | `flutter_multicast_lock` | MIT | OK | Go (runtime dep) | Android SSDP only |
| 2026-05-22 | Agent (TVREMOTE-32) | Full `pubspec.yaml` direct deps + assets + protocol audit | Yes (pub cache LICENSE) | OK — permissive OSS set | **Go** (OSS/attribution) | Manufacturer ToS + 2 streaming trademarks still pending |
