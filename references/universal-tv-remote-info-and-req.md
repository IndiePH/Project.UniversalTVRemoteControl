# Universal TV Remote App — Information & Requirements

> **Role:** Background reference (framework comparison, OEM protocol survey, compliance tables, risk register). **Source of truth** for product and tasks: `references/product_specs.md`, `references/implementation_tasks.md`, `references/marketing_strategy.md`. **Naming:** OneRemote / Universal TV Remote — see `references/product_specs.md`. **Store checklist:** `references/compliance-and-release-requirements.md`. Policies (IAP, ATT, GDPR) are standard; **TV OEM details** change—verify against current manufacturer docs.

---

## 1. Project Overview

Flutter app for Android and iOS; **Android and iOS compatible**; **release** timelines may differ. Monetization: free + ads; optional one-time purchase to remove ads. Scope: Wi‑Fi control of multiple TV brands (IR/legacy: §3.2; detail `references/product_specs.md`).

---

## 2. Framework Recommendation

### 2.1 Recommendation: Flutter

Flutter is the recommended framework for this project. A universal remote app is primarily driven by
network communication — sending commands over Wi-Fi to different TV brands. Flutter handles this well
with a single shared codebase for both iOS and Android, cutting development and maintenance cost
roughly in half compared to building two separate native apps.

The official Flutter plugin ecosystem covers all three key integration needs for this project:

| Need | Flutter Plugin |
|---|---|
| In-app purchase (remove ads) | `in_app_purchase` (official Flutter plugin) |
| Ads | `google_mobile_ads` (official Google plugin) |
| iOS ad tracking permission | `app_tracking_transparency` |

### 2.2 Framework Options Comparison

| | Native (Swift + Kotlin) | Flutter *(Recommended)* | React Native |
|---|---|---|---|
| **Codebases** | 2 separate | 1 shared | 1 shared |
| **Language** | Swift (iOS) + Kotlin (Android) | Dart | JavaScript / TypeScript |
| **Performance** | Best | Very good | Good (with New Architecture) |
| **Hardware access** | Full, direct | Via platform channels | Via native modules |
| **IR blaster access** | Full (Android only) | Via platform channel | Via native module |
| **Hiring market** | Large (two pools) | Growing | Large (JS developers) |
| **Best for** | Premium UX or deep hardware needs | Cross-platform with strong performance | JS-first teams |

### 2.3 Tradeoff Summary

| Option | Business upside | Business downside | Risk |
|---|---|---|---|
| **Native** | Full hardware access, no framework dependency | Double development time and cost | Scope/cost overrun on small teams |
| **Flutter** | Single codebase, good performance, covers all network needs | Dart has a smaller hiring pool | Bridging work needed if deep IR hardware access required |
| **React Native** | Widest hiring pool (JavaScript) | Weakest performance for real-time command-sending | Framework version churn; bridge overhead |

---

## 3. TV Platform Integration

### 3.1 Communication Methods by Brand

Each TV brand uses its own protocol. A universal remote must integrate each one separately.

| Brand / Platform | Communication Method | Notes |
|---|---|---|
| **Samsung Smart TVs** | Wi-Fi — Samsung SmartThings / proprietary WebSocket protocol | Requires Samsung developer registration |
| **LG Smart TVs** | Wi-Fi — webOS / LG ThinQ API | Requires LG developer registration |
| **Hisense (VIDAA)** | Wi-Fi — vendor-specific / MQTT-style paths (see project adapters) | MVP target (`references/product_specs.md`); validate per model |
| **Sony Bravia** | Wi-Fi — BRAVIA IP Control (HTTP/REST) | Well-documented; **not** MVP for OneRemote unless promoted in specs |
| **Roku** | Wi-Fi — External Control Protocol (ECP) | Open, REST-based, easiest brand to integrate |
| **Android TV / Google TV** | Wi-Fi — Google Cast SDK or ADB | Covers TCL, Hisense, Sony Android TV, Chromecast |
| **Apple TV** | Wi-Fi — AirPlay / HomeKit | Requires Apple developer account and entitlements |
| **Legacy / older TVs** | Infrared (IR) signal | See Section 3.2 |

**Scope:** Brand targets and store copy rules: `references/product_specs.md`, `references/marketing_strategy.md`. Do not list brands in stores until the build supports them on hardware.

> **Verify before integrating:** Samsung, LG, and others update their developer APIs periodically.
> Confirm current protocol versions and terms at each manufacturer's developer portal.

### 3.2 IR vs Wi-Fi — Key Decision

Infrared (IR) is required for legacy TVs that are not internet-connected.

| | Wi-Fi Only | Wi-Fi + IR |
|---|---|---|
| **iOS support** | Full support | iOS has no IR hardware — IR not possible from iPhone |
| **Android support** | Full support | Some Android phones have a built-in IR blaster |
| **Alternative for iOS IR** | — | Use an external IR hub device (e.g., Broadlink RM4, SwitchBot Hub) connected to the home network; app sends commands to the hub, hub blasts IR |
| **Added complexity** | Low | Medium-High (extra hardware dependency for users) |

**Recommendation:** Unless your target audience explicitly includes legacy TV owners, start with
Wi-Fi smart TVs only. IR support can be added later via an IR hub integration.

IR / hubs: `references/product_specs.md` (iOS has no phone IR; LAN IR hub = Post-MVP).

---

## 4. Monetization Strategy

### 4.1 Model

- **Free tier:** App is free to download and use, with non-intrusive ads shown.
- **Paid tier:** One-time in-app purchase permanently removes all ads ("non-consumable" purchase type).

**Detail:** Pro vs roadmap “Premium” (`references/product_specs.md` §7, `references/marketing_strategy.md`). IAP: platform billing only—§4.2.

### 4.2 In-App Purchase Platform Requirements

> **Hard requirement:** Both Apple and Google mandate that all in-app purchases of digital content
> must go through their own payment systems. You cannot use Stripe, PayPal, or any external payment
> processor for digital goods inside the app. Violation results in app rejection or removal.

| Platform | Required System | Where to Configure |
|---|---|---|
| **iOS** | Apple In-App Purchase | App Store Connect (developer portal) |
| **Android** | Google Play Billing | Google Play Console |

Set up the "remove ads" product as a **non-consumable** in-app purchase on both platforms — this
means it is purchased once and applied permanently to that user's account.

### 4.3 Revenue Share

| Tier | Apple | Google |
|---|---|---|
| Standard | 30% | 30% |
| Small developer program | 15% (under $1M/year revenue) | 15% (first $1M/year) |

**Example:** A $2.99 "remove ads" purchase nets you approximately $2.09–$2.54 after platform fees,
depending on which tier applies.

**See also:** `references/product_specs.md` §8; `references/marketing_strategy.md` §3 (**$1.99** Pro price).

---

## 5. Compliance & Legal Requirements

Mandatory before store submission. **Canonical checklist:** `references/compliance-and-release-requirements.md`. Summaries: `references/product_specs.md` §8, `references/implementation_tasks.md` (Final Release Gate). Below: **short reference** only.

### 5.1 Privacy Policy

**Both stores require a publicly accessible Privacy Policy URL** if your app shows ads or collects
any user data.

- Must be live at a public URL before app submission
- Must describe what data is collected, how it is used, and how users can request deletion
- A simple hosted webpage is sufficient (no legal template required, but accuracy is important)

### 5.2 Ad-Related Compliance

| Requirement | Platform | What to Do |
|---|---|---|
| **App Tracking Transparency (ATT)** | iOS 14.5+ | Must request user permission before showing personalized ads. Use the `app_tracking_transparency` Flutter plugin. Skipping this = rejection. |
| **GDPR consent (EU users)** | Both | Must show a consent dialog before loading ads for EU users. Use Google's UMP (User Messaging Platform) SDK — handles this automatically via the `google_mobile_ads` plugin. |
| **CCPA consent (California users)** | Both | Handled by the same UMP SDK as GDPR. |
| **COPPA (users under 13)** | Both | If your app may be used by children under 13, special restrictions apply to ad targeting. Define your target age group clearly in store listings. |

### 5.3 TV Manufacturer API Terms

Before integrating each TV brand's protocol, review their developer terms of service:

- Some manufacturers require a formal developer agreement for commercial use
- Some APIs are freely accessible; others require registration or approval
- This applies especially to Samsung (SmartThings) and LG (ThinQ) integrations

Manufacturer API / ToS: `references/third_party_licenses.md`, `references/product_specs.md` §8.

---

## 6. Development Requirements

### 6.1 Knowledge Required

| Area | Details |
|---|---|
| Flutter / Dart fundamentals | Core framework for building the app |
| Network programming | Sending and receiving commands over a local Wi-Fi network (HTTP, WebSockets, UDP) |
| TV device discovery | How smart TVs announce themselves on a network (SSDP / UPnP / mDNS protocols) |
| Per-brand protocol | Each TV brand's specific command format (see Section 3.1) |
| In-app purchase integration | Apple IAP + Google Play Billing via `in_app_purchase` plugin |
| Ad integration + consent | AdMob setup, ATT permission flow, UMP consent dialog |

### 6.2 Tools & Accounts

| Tool / Account | Cost | Purpose |
|---|---|---|
| Apple Mac computer | Hardware cost | Required to build and sign iOS apps — no alternative |
| Xcode (free) | Free | iOS build tool (Mac only) |
| Android Studio (free) | Free | Android builds and emulator |
| Flutter SDK | Free | Cross-platform framework |
| Apple Developer Program | $99 / year | Required for TestFlight, App Store submission, IAP setup |
| Google Play Developer account | $25 one-time | Required for Play Store submission, Play Billing setup |
| Google AdMob account | Free | Ad network for showing ads in-app |
| Privacy Policy hosting | Free | Any public webpage (GitHub Pages, Notion, etc.) |

**Also reflected in:** `references/compliance-and-release-requirements.md` §3 (accounts / tools table).

### 6.3 Testing Requirements

| What to Test On | Why |
|---|---|
| Physical Android device | Device discovery over real Wi-Fi cannot be reliably tested on an emulator |
| Physical iPhone or iPad | Same reason — real network behavior required |
| At least one smart TV per brand you support | Each brand's integration must be tested end-to-end |
| IR hub device (if supporting legacy TVs) | IR cannot be tested without the physical hardware |

Physical TV validation: **release gate** (`references/implementation_tasks.md` Final Release Gate); automated tests complement, not replace.

---

## 7. Risk Register

Severity/likelihood view for planning. **Checklist:** `references/compliance-and-release-requirements.md`.

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| Using third-party payment processor for IAP | HIGH | N/A | Use Apple IAP + Google Play Billing only — non-negotiable |
| Missing ATT permission dialog on iOS | HIGH | CERTAIN if omitted | Implement `app_tracking_transparency` plugin before first ad loads |
| Missing GDPR/CCPA consent screen | HIGH | HIGH (EU/CA users) | Integrate Google UMP SDK — handles consent automatically |
| No Privacy Policy at submission | HIGH | CERTAIN if omitted | Publish privacy policy page before submitting to either store |
| TV manufacturer API restricts commercial use | MEDIUM | MEDIUM | Review developer terms for each brand before integrating |
| App Store review rejection | MEDIUM | LOW | Ensure app is fully functional; document features clearly in submission |
| Platform revenue share reducing IAP income | MEDIUM | CERTAIN | Price IAP accounting for 15–30% fee; small developer programs reduce this to 15% |
| IR support gaps on iOS | MEDIUM | HIGH if IR targeted | Use external IR hub integration or limit IR to Android only |

---

## 8. Open Questions

- [x] Which TV brands are in scope for the initial release? — **Answered:** Samsung, LG, Hisense (MVP); Roku, Android TV Post-MVP. (`references/product_specs.md`)
- [x] Will IR / legacy TV support be included at launch or deferred? — **Answered:** Deferred Post-MVP. (`references/product_specs.md`)
- [x] Who is building the app? — **Answered:** Two-person team, both using coding agents (one workflow centered on **Cursor**, one on **Claude**). **Person A (Cursor):** UI + **Samsung** + **Hisense** brand code. **Person B (Claude):** **reference docs** + **LG** brand code. Detail: **Team & work split** in `references/implementation_tasks.md`. **Merge conflicts** on shared files remain a managed risk.
- [x] What is the target launch date? — **Answered:** **End of May 2026**; earlier ship date if the product is ready sooner. (`references/implementation_tasks.md` Planning Notes)
- [x] What price point is planned for the "remove ads" purchase? — **Answered:** $1.99 USD. (`references/marketing_strategy.md`)
