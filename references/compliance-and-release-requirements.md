# Compliance & Production Release Requirements

**OneRemote** (internal: **Universal TV Remote** — `references/product_specs.md`).

**This file** is the submission checklist. Summaries also live in `references/product_specs.md` §8 and `references/implementation_tasks.md` (Final Release Gate; Markdown task-list bullets)—keep them aligned when rules change.

---

## 1. Hard Store-Submission Blockers

These will cause **rejection or removal** from the App Store / Google Play if missing.

### 1.1 App Tracking Transparency — iOS only

- [ ] Integrate the `app_tracking_transparency` Flutter plugin
- [ ] Request ATT permission **before** any ad loads — not after, not lazily
- [ ] Handle both granted and denied states gracefully (ads must degrade, not crash)

> Apple mandates this on iOS 14.5+. Skipping it = automatic App Store rejection.

---

### 1.2 GDPR + CCPA Consent Screen — both platforms

- [ ] Integrate Google's UMP (User Messaging Platform) SDK via the `google_mobile_ads` plugin
- [ ] Show consent dialog before loading any ads for EU and California users
- [ ] UMP SDK handles both GDPR and CCPA — one integration covers both

> Required for all users in EU and California. Both Apple and Google enforce this at review.

---

### 1.3 Privacy Policy

- [ ] Write a Privacy Policy describing: what data is collected, how it is used, how users can request deletion
- [ ] Host it at a **live, publicly accessible URL** (GitHub Pages, Notion, or similar is sufficient)
- [ ] Add the URL to the App Store Connect listing before submission
- [ ] Add the URL to the Google Play Console listing before submission

> Both stores require a Privacy Policy URL at submission time if the app shows ads or collects any user data. This is a hard gate — submission is rejected without it.

---

### 1.4 In-App Purchase — Platform Payment Systems Only

- [ ] All "remove ads" purchases must go through **Apple In-App Purchase** (iOS) and **Google Play Billing** (Android)
- [ ] Do not use Stripe, PayPal, or any external payment processor for digital goods inside the app
- [ ] Set up the "remove ads" product as a **non-consumable** IAP in App Store Connect
- [ ] Set up the "remove ads" product as a **non-consumable** in Google Play Console
- [ ] Integrate via the `in_app_purchase` Flutter plugin (official)

> Violation of this rule results in app rejection or removal from both stores. This is non-negotiable.

---

## 2. Legal / Commercial Blockers

These won't trigger automated rejection but expose the project to API termination or legal risk after launch.

### 2.1 TV Manufacturer API Terms of Service

- [ ] **Samsung (SmartThings):** Review developer terms at Samsung's developer portal before commercial release. A formal developer agreement may be required.
- [ ] **LG (ThinQ / webOS):** Review developer terms at LG's developer portal. Registration or approval may be required for commercial use.
- [ ] **Hisense (VIDAA):** Verify whether commercial use of the VIDAA protocol requires any agreement.
- [ ] Record the outcome of each review in `third_party_licenses.md`

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

- [ ] Define the target age group clearly in both store listings
- [ ] If the app may reach users under 13, ad targeting restrictions apply — review AdMob's child-directed content settings

> For a TV remote app, COPPA is unlikely to apply, but the age group must be explicitly declared in store listings.

---

## Checklist Summary

| Requirement | Platform | Blocker Type | Done |
|---|---|---|---|
| ATT permission dialog | iOS | Store rejection | ☐ |
| GDPR/CCPA consent screen (UMP) | Both | Store rejection | ☐ |
| Privacy Policy at live URL | Both | Store rejection | ☐ |
| IAP via Apple/Google only | Both | Store rejection / removal | ☐ |
| Samsung API ToS review | Both | Legal / API access | ☐ |
| LG API ToS review | Both | Legal / API access | ☐ |
| Hisense API ToS review | Both | Legal / API access | ☐ |
| Apple Developer Program account | iOS | Cannot submit | ☐ |
| Google Play Developer account | Android | Cannot submit | ☐ |
| AdMob account | Both | Ads cannot go live | ☐ |
| Physical device validation (Samsung) | Android | Quality gate | ☐ |
| Physical device validation (LG) | Android | Quality gate | ☐ |
| Physical device validation (Hisense) | Android | Quality gate | ☐ |
| COPPA age group declaration | Both | Policy compliance | ☐ |
