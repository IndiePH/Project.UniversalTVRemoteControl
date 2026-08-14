# Compliance & Production Release Requirements

**OneRemote** (internal: **Universal TV Remote** — `references/product_specs.md`).

**This file** is the submission checklist. Summaries also live in `references/product_specs.md` §8 and `references/implementation_tasks.md` (Final Release Gate; Markdown task-list bullets)—keep them aligned when rules change.

---

## 1. Hard Store-Submission Blockers

These will cause **rejection or removal** from the App Store / Google Play if missing.

### 1.1 App Tracking Transparency — iOS only

- [x] Integrate the `app_tracking_transparency` Flutter plugin
- [x] Request ATT permission **before** any ad loads — via `AdConsentCoordinator.prepareForAds()` ahead of `MobileAds.initialize()` in `main.dart`
- [ ] Handle both granted and denied states gracefully on device (ads must degrade, not crash — code paths exist; physical validation pending)

> Apple mandates this on iOS 14.5+. Skipping it = automatic App Store rejection.

---

### 1.2 GDPR + CCPA Consent Screen — both platforms

- [x] Integrate Google's UMP (User Messaging Platform) SDK via the `google_mobile_ads` plugin (`AdConsentCoordinator`)
- [x] Gather consent before initializing the Mobile Ads SDK; banner/interstitial placements check `AdConsentCoordinator.canRequestAds`
- [x] Settings sheet exposes UMP privacy-options form when required
- [ ] EU/California behavioral validation on physical devices before release ads go live

> Required for all users in EU and California. Both Apple and Google enforce this at review.

> Note: `google_mobile_ads` renders banner + interstitial scaffolds via `lib/app/ads/`
> (see `references/changelog.md` 2026-05-13 and 2026-05-20). UMP + ATT are integrated
> in app code; production AdMob IDs and regional device validation remain release blockers.

---

### 1.3 Privacy Policy

- [ ] Write a Privacy Policy describing: what data is collected, how it is used, how users can request deletion
- [ ] Host it at a **live, publicly accessible URL** (GitHub Pages, Notion, or similar is sufficient)
- [x] In-app link scaffold: `AppLegalUrls` + `LegalLinkLauncher` + settings-sheet entry (URL must be set before release)
- [ ] Add the URL to the App Store Connect listing before submission
- [ ] Add the URL to the Google Play Console listing before submission

> Both stores require a Privacy Policy URL at submission time if the app shows ads or collects any user data. This is a hard gate — submission is rejected without it.

---

### 1.5 In-app user feedback

- [x] In-app form (category + message + Send) in Settings — no external browser for primary feedback
- [x] Submission via configurable HTTPS webhook (`FeedbackConfig` / `HttpFeedbackSubmissionService`)
- [x] Default `FEEDBACK_WEBHOOK_URL` in release builds via `FeedbackConfig` (Apps Script → Sheet; override with `--dart-define`; see `references/feedback-collection-setup.md`)
- [ ] **Production:** set `FEEDBACK_WEBHOOK_TOKEN` and validate on the server/script side (**TVREMOTE-69**)
- [x] Privacy policy mentions voluntary feedback including paired TV brand/model (`legal-docs` updated 2026-08-14; deploy to GitHub Pages before release build with `pairedModels`)

> Override the webhook URL only when pointing at a non-default deployment. Confirm the Apps Script `doPost` + `Feedback` sheet tab are deployed before store release.

---

### 1.4 In-App Purchase — Platform Payment Systems Only

- [ ] All "remove ads" purchases must go through **Apple In-App Purchase** (iOS) and **Google Play Billing** (Android)
- [ ] Do not use Stripe, PayPal, or any external payment processor for digital goods inside the app
- [ ] Configure the store products for **Pro** (removes ads + unlocks Pro features) in App Store Connect / Google Play Console
- [ ] Pro may be offered as **subscriptions** and/or a **lifetime** one-time purchase depending on the release plan; the app must only reference product IDs that exist in the store project for that environment
- [x] Integrate via the `in_app_purchase` Flutter plugin (official) — **TVREMOTE-66**
- [x] Product IDs are configured in app code (`ProProductIds` catalog: weekly/monthly/annual/lifetime) and can be overridden per build via `--dart-define=PRO_PRODUCT_ID=...` (see `lib/app/configurations/app_monetization_di_config.dart`)
- [x] On app launch, call `refreshFromStore()` / restore path and gate banner, interstitial, and layout-editor Pro features by verified entitlement; entitlement refresh on app resume
- [x] Android server-side receipt validation: Flutter client (`ProReceiptValidationService`) + Firebase callable `verifyProAndroidPurchase` in `functions/` (Play subscriptionsv2 + legacy fallback); operator deploy/configure per `references/goals/goal-pro-receipt-validation-remote-setup.md`
- [ ] End-to-end sandbox purchase + restore validated on signed builds with live store products and deployed validation function (**TVREMOTE-67**)
- [ ] **Future (iOS):** implement App Store receipt / subscription validation in the backend (Firebase Cloud Functions) to mirror Android receipt validation and support subscription expiry/cancellation correctly.

> Violation of this rule results in app rejection or removal from both stores. This is non-negotiable.

---

## 2. Legal / Commercial Blockers

These won't trigger automated rejection but expose the project to API termination or legal risk after launch.

### 2.1 TV Manufacturer API Terms of Service

- [ ] **Samsung (SmartThings):** Review developer terms at Samsung's developer portal before commercial release. A formal developer agreement may be required.
- [ ] **LG (ThinQ / webOS):** Review developer terms at LG's developer portal. Registration or approval may be required for commercial use.
- [ ] **Hisense (VIDAA):** Verify whether commercial use of the VIDAA protocol requires any agreement.
- [ ] Record the outcome of each review in `third_party_licenses.md` (OSS dependency + in-app license pass recorded **2026-05-22** — **TVREMOTE-32**; per-OEM ToS rows still open)

> Shipping without complying with manufacturer API terms risks access being revoked post-launch.

---

## 3. Pre-Submission Prerequisites

Without these accounts, submission is physically impossible regardless of code readiness.

| Account / Tool | Cost | Required For | Status |
|---|---|---|---|
| Apple Developer Program | $99 / year | App Store submission, TestFlight, IAP setup in App Store Connect | ☐ |
| Google Play Developer account | $25 one-time | Play Store submission, Play Billing setup in Play Console | ☐ |
| Google AdMob account | Free | Ad network — required before ad integration goes live | ☐ |
| Privacy Policy hosting | Free | Publicly accessible URL required at submission | ☐ |
| Apple Mac computer | Hardware cost | Required to build and sign iOS apps — no alternative exists | ☐ (when producing signed iOS builds) |

---

## 4. Physical Device Testing Gate

Code-level tests (widget/integration) are necessary but not sufficient. Each brand must be validated on physical hardware before being claimed as supported in store listings.

| What to test on | Why |
|---|---|
| Physical Android device | Device discovery over real Wi-Fi cannot be reliably tested on an emulator |
| Physical iPhone or iPad | Same — real network behavior required before iOS release to users |
| At least one physical TV per supported brand | Each brand integration must be tested end-to-end |

> This formalizes the "Validation Gate" column already present in the brand readiness matrix in
> `product_specs.md`. A brand is not releasable until it passes on physical hardware.

---

## 5. COPPA (Users Under 13)

- [x] Define the target age group clearly in both store listings (**13+** on Play Console)
- [ ] If the app may reach users under 13, ad targeting restrictions apply — review AdMob's child-directed content settings

> For a TV remote app, COPPA is unlikely to apply. Play Console target audience is **13+**; content rating may still show “all ages” separately.

---

## 6. Play Store listing copy

Canonical short and full descriptions: **`references/marketing_strategy.md` §2**.

| Field | Status |
| --- | --- |
| Short description (≤ 80 chars) | Draft in marketing_strategy.md — paste into Play Console |
| Full description | Draft in marketing_strategy.md — includes ads, Pro, four brands, privacy URLs |
| Listed brands match shipped build | Samsung, LG, Hisense, Chromecast with Google TV only |
| Privacy policy URL in listing | `https://yoxent.github.io/legal-docs/one-remote/privacy-policy.html` |
| Data deletion URL | `https://yoxent.github.io/legal-docs/one-remote/account-and-data-deletion.html` |

---

## Checklist Summary

| Requirement | Platform | Blocker Type | Done |
|---|---|---|---|
| ATT permission dialog | iOS | Store rejection | ☐ |
| GDPR/CCPA consent screen (UMP) | Both | Store rejection | ☐ |
| Privacy Policy at live URL | Both | Store rejection | ☐ |
| Production feedback webhook token (`FEEDBACK_WEBHOOK_TOKEN`; default URL in `FeedbackConfig`) | Both | Support / quality | ☐ |
| IAP via Apple/Google only | Both | Store rejection / removal | ☐ |
| Samsung API ToS review | Both | Legal / API access | ☐ |
| LG API ToS review | Both | Legal / API access | ☐ |
| Hisense API ToS review | Both | Legal / API access | ☐ |
| Apple Developer Program account | iOS | Cannot submit | ☐ |
| Google Play Developer account | Android | Cannot submit | ☐ |
| AdMob account | Both | Ads cannot go live | ☐ |
| Swap test AdMob ids for production (`AndroidManifest.xml`, `Info.plist` `GADApplicationIdentifier` + full `SKAdNetworkItems`, `--dart-define` banner unit IDs) | Both | Ads cannot go live | ☐ |
| Physical device validation (Samsung) | Android | Quality gate | ☐ |
| Physical device validation (LG) | Android | Quality gate | ☐ |
| Physical device validation (Hisense) | Android | Quality gate | ☐ |
| COPPA age group declaration | Both | Policy compliance | ☐ |
