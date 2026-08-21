# 📱 OneRemote – Product & Monetization Strategy (Play listing examples; mirror structure for App Store)

---

# 1. 🧠 Brand Identity

**Naming:** `references/product_specs.md` (title block). **Identifiers:** `com.vorithstudio.smarttvremote` (Android), `OneRemote`.

## App Name (Store Title)
OneRemote – Smart TV Remote

## Brand Name (Logo / Package)
OneRemote

## Package Name (Android — shipped)
com.vorithstudio.smarttvremote

---

# 2. 📄 Play Store Listing

**Last updated:** 2026-08-21 · **Target audience:** 13+ · **Listed brands:** Samsung, LG, Hisense, Chromecast with Google TV only (no Roku/TCL until validated).

## 🔹 Short Description (80 chars max)

```
Control Samsung, LG, Hisense & Chromecast with Google TV over WiFi.
```

*(65 characters)*

**Alternate (72 chars):**

```
WiFi remote for Samsung, LG, Hisense & Chromecast with Google TV. No IR.
```

---

## 🔹 Full Description

Copy below for Google Play Console → Main store listing → Full description. Plain text; line breaks preserved.

```
OneRemote – Smart TV Remote

Turn your phone into a WiFi TV remote — no IR blaster required. OneRemote discovers TVs on your home network, pairs with your TV's approval, and gives you a clean remote for everyday control.

Supported TVs (WiFi, same network)
• Samsung Smart TVs (Tizen)
• LG Smart TVs (webOS)
• Hisense smart TVs (VIDAA — model compatibility varies)
• Chromecast with Google TV (Android TV Remote Protocol)

Not supported: Cast-only Chromecast dongles without Google TV, Roku, or TVs that require an IR remote.

Key features
• WiFi control — phone and TV on the same network
• Automatic TV discovery on your network
• Core remote: power, volume, input, D-pad navigation, home/back
• On-screen keyboard for search and text entry where the TV supports it
• Save paired TVs and reconnect quickly
• Keeps paired TVs after a router reboot / new IP when the TV can be identified again (no re-pair in the common case)
• Optional in-app feedback to report issues (category + message; see Privacy Policy)

Free and Pro
• Free: full remote features with ads (banner ads and occasional full-screen ads after consent where required)
• Pro: remove ads, unlock premium themes and customizable button layouts
• Pro plans: weekly, monthly, yearly, or lifetime — purchased through Google Play only

How to use
1. Connect your phone and TV to the same WiFi
2. Open OneRemote and select your TV
3. Approve the connection on your TV when prompted
4. Start controlling your TV

Important notes
• TV and phone must be on the same Wi‑Fi network
• Some TVs require a one-time pairing PIN or on-screen approval
• Features and keyboard support depend on TV brand and model
• Chromecast with Google TV support uses the Android TV remote protocol; Cast-only devices are not supported

Privacy
Privacy Policy: https://yoxent.github.io/legal-docs/one-remote/privacy-policy.html
Account & data deletion: https://yoxent.github.io/legal-docs/one-remote/account-and-data-deletion.html

Download OneRemote and control your Smart TV from your phone.
```

---

### Listing alignment checklist

| Item | Value / note |
| --- | --- |
| Short description | ≤ 80 chars; includes all four listed brands |
| Full description | Matches shipped adapters only; Chromecast = **with Google TV** |
| Target audience | 13+ (Play Console → Target audience) |
| Privacy policy URL | `https://yoxent.github.io/legal-docs/one-remote/privacy-policy.html` |
| Data deletion URL | `https://yoxent.github.io/legal-docs/one-remote/account-and-data-deletion.html` |
| Ads disclosure | Banner + interstitial (not banner-only) |
| In-app products | Weekly / monthly / yearly subscriptions + lifetime Pro |

---

## 🔹 Release details (AAB — Google Play)

**Current release:** `1.4.1` · **versionCode:** `19` · **Track:** Internal testing → Production (promote same artifact when validated)

**Focus for this release:** Persistent TV identity — paired TVs, layouts, and pairing credentials survive DHCP / IP changes when the TV can be re-identified. No Play Console Data safety form change (stable ids and pairing secrets stay on-device; no new data leaves the device).

**Build (signed AAB with production dart-defines):**

```powershell
cd E:\Projects\Flutter\one_remote
.\scripts\build_release_android.ps1
```

Requires `android/release_dart_defines.properties` (gitignored) with `FEEDBACK_WEBHOOK_TOKEN` matching Apps Script `FEEDBACK_TOKEN`. See `references/feedback-collection-setup.md`.

**Artifact:** `build/app/outputs/bundle/release/app-release.aab`

### Play Console — Release notes (en-US)

Paste under **Release → Release notes** (Internal testing or Production). Adjust length if Console limits apply.

```
What's new in 1.4.1

• Paired TVs stay connected after a router reboot or new IP when the TV can be identified again — no re-pair needed in the common case
• Saved layouts and pairing stay with the TV across IP changes
• Feedback can include saved TV brand/model (when known) to help support — disclosed before send; no IP addresses or pairing secrets
• Stability and reconnect improvements

Thank you for using OneRemote!
```

**Shorter variant (if character limit is tight):**

```
• Paired TVs keep working after router reboot / new IP (no re-pair in common cases)
• Saved layouts and pairing survive IP changes
• Stability improvements
```

### Operator checklist (this AAB)

| Step | Done |
| --- | --- |
| Apps Script `FEEDBACK_TOKEN` matches build `FEEDBACK_WEBHOOK_TOKEN` | ☐ |
| Sheet column **L** `pairedModels`; FILTER formulas use `A:L` | ☐ |
| Privacy policy live (pairedModels §2.1) | ☐ |
| Data safety form unchanged (no new collected/shared data for this release) | ☐ |
| Firebase Remote Config `test_ads_enabled` = `false` | ☐ |
| Upload AAB to **Internal testing** | ☐ |
| Verify: pair TV, Pro purchase/restore, ads, feedback row in Sheet | ☐ |
| Verify: reboot router / change TV IP, rediscover, reconnect without re-pair when identity is known | ☐ |
| Update Main store listing full description with the IP-resilience feature bullet | ☐ |
| Promote to **Production** (staged rollout recommended) | ☐ |

---

# 3. 💰 Monetization Strategy

## 🟢 Free Version (Base App)
- Full remote controls for supported brands  
- Ads after consent where required: bottom banner + occasional interstitial (engagement-gated; not during pairing)  
- Limited themes (1–2 only)  
- Fixed layout only  

---

## 🔵 Pro Version

### 💵 Price
Target USD pricing (storefronts localize currency automatically):
- Weekly: **$3.99**
- Monthly: **$7.99**
- Yearly: **$24.99**
- Lifetime: **$14.99**

Rationale: aligned to competitor pricing, with intentionally lower price points to improve conversion.

---

## 🎁 Pro Features
- 🚫 No ads  
- 🎨 Custom layouts  
- 🌈 Premium themes & colors  
- ⚡ Cleaner UI experience  

**IAP rule:** Pro must be sold with **Apple In-App Purchase** (iOS) and **Google Play Billing** (Android)—no external payment links for digital unlocks inside the app.

**Scope note:** `references/product_specs.md` also lists broader Post-MVP “Premium” ideas (voice, automation, custom remotes). Keep marketing promises aligned with what is actually in the Pro SKU at release.

---

# 4. 📢 Ad Strategy

## 🟢 Ad Type Strategy (shipped)
- **Banner ads** — bottom of remote home (free tier)
- **Interstitial ads** — occasional full-screen ads after consent (UMP) and engagement policy; not on first launch or during pairing

Avoid:
- Full-screen ads on launch  
- Ads during pairing or connection loading  
- Aggressive interstitial frequency  

**Store copy:** Disclose both banner and interstitial ads in the full description and Play Console Data safety / ads declarations.

---

## 📍 Ad Placement

### Home Screen
- Bottom banner ad

### Connected Screen
- Bottom banner ad remains visible

### DO NOT place ads:
- During pairing  
- During button presses  
- During connection loading  

---

## 🧠 Why this works
- Non-intrusive UX  
- Higher retention  
- Better Pro conversion  

---

# 5. 💡 Pro Upgrade Strategy

## 🎯 When to show upgrade prompt
BEST MOMENTS:
- After successful TV pairing  
- After 2–3 minutes of usage  
- When user opens Themes/Layout section  

NEVER show:
- On first launch  
- Before connection succeeds  

---

## 🟡 Upgrade Popup Copy

### Title
Upgrade to OneRemote Pro

### Body
Enjoy a cleaner, faster, and fully customizable remote experience.

### Features
- No ads  
- Custom layouts  
- Premium themes & colors  

### CTA
Unlock Pro

---

## 🔥 Alternative Emotional Copy

Make your remote experience cleaner and truly yours.

---

# 6. 🎯 Paywall Strategy

## Free users should SEE Pro features:
- Locked themes (🔒)  
- Locked layouts  
- “Pro” tags on premium features  

---

# 7. 📈 Expected Performance

- Conversion rate: 2% – 6%  
- Majority remain free users with ads  
- Ratings improve with non-intrusive ads  

---

# 8. 🧠 Strategy Summary

- OneRemote = brand identity  
- SEO keywords in description, not spammed  
- Banner + conservative interstitials (consent-gated)  
- Pro = quality-of-life upgrades  
- Upsell at “happy moments”  