# 📺 Universal TV Remote App — Product Specification

## 1. Product Overview

**Working Name:** RemoteOne
**Platform:** Android (MVP), iOS (Post-MVP)
**Category:** Utility / Smart Home

### Goal

Create a mobile app that allows users to control TVs using:

* Infrared (IR blaster phones)
* Wi-Fi (Smart TVs via local network)
* Optional cloud pairing for remote access *(Post-MVP exploration)*

### Core Value Proposition

One app to control almost any TV—fast, simple, and no setup headaches.

### Current Planning Baseline

This specification is a living document. It is the current source of truth, but scope and sequencing may evolve as implementation feedback is gathered.

---

## 2. Target Users

### Primary

* Users who lost their physical remote
* People with multiple TVs (different brands)
* Renters / dorm users

### Secondary

* Tech-savvy users who want automation
* Smart home enthusiasts

---

## 3. Key Features

### 3.1 Core Features (MVP)

MVP implementation priority (current baseline):

1. Android app
2. Wi-Fi TV control
3. Samsung, LG, and Hisense support (hardware-available first)
4. iOS-compatible architecture decisions during Android development
5. Fast, reliable core remote experience

#### Device Connection

* **IR Mode**

    * Detect IR blaster availability *(Post-MVP implementation; keep hooks only in MVP architecture)*
    * Use brand-based presets *(Post-MVP)*

* **Wi-Fi Mode**

    * Scan local network for TVs
    * Current MVP implementation uses SSDP-based discovery on local network (with manual IP fallback)
    * Pairing UX behavior (current baseline):
        * selecting a TV starts a blocking pairing state on the pairing page
        * the app does not return to the remote screen until pairing succeeds
        * Samsung pairing explicitly waits for TV-side approval before success is reported
    * Support in MVP:

        * Samsung (Tizen)
        * LG (webOS)
        * Hisense (VIDAA, capability permitting)
    * Additional TV brands are enabled as protocol adapters mature and testing becomes available

---

#### Remote Control UI

* Power ON/OFF
* Volume +/-
* Channel +/-
* Mute
* Input / Source
* Navigation Pad (↑ ↓ ← → OK)
* Back / Home / Menu
* Text input keyboard for TV search/forms
* Settings button (opens remote customization options)
* Immediate visual feedback on every button press

---

#### Brand Selection System

* Manual brand/protocol selection for Wi-Fi pairing
* Save working configuration only after successful protocol-level pairing confirmation
* "Does this work?" signal-testing flow for IR remains Post-MVP
* Prioritize tested presets for Samsung, LG, and Hisense first

---

#### Remote Customization

* Settings access on remote screen toggles an in-place layout editor
* Grid-based layout customization (`5x9`) with drag-and-drop repositioning
* Occupied-cell drop swaps controls instead of rejecting the move
* Multi-cell control support:
    * D-pad occupies `3x3`
    * Search control occupies `5x1` (`4x1` text field + `1x1` right-side icon action)
    * Channel and volume rockers occupy vertical `1x3` footprints
* Save and restore selected layout per device
* Reset layout action restores default control coordinates for current device

---

#### Favorites / Saved Devices

* Save multiple TVs *(Phase 2 target)*
* Quick switching between devices *(Phase 2 target)*
* Pairing a new TV is allowed while another TV is active:
    * on successful pair, active control switches to the newly paired TV
    * previously paired TVs remain saved until user removes them
* Active saved-device removal requires explicit typed confirmation (`REMOVE`)

---

### 3.2 Post-MVP Features

#### Smart Features

* Voice control (Google Assistant / Siri)
* Gesture controls
* Custom button mapping

#### Automation

* “Watch Mode” (power + input preset)
* Scheduling (auto-off timer)

#### Advanced

* Remote over internet (account-based)
* Widgets / lockscreen controls
* Wearable support (Wear OS / Apple Watch)

---

## 4. User Flow

### First-Time Experience

1. Open app
2. Show connection method options:

    * Scan Wi-Fi devices (default MVP path)
    * Select brand/protocol manually
3. Discover and select TV
4. Pair/connect to selected TV
   - keep user on pairing screen with blocking loading state while pairing is in progress
   - for Samsung, wait for TV authorization prompt approval before marking success
5. Test core commands (power/volume/navigation)
6. Verify text input works using in-app keyboard
7. Save device
8. Land on remote screen
9. Optional: open Settings to choose preferred button layout

---

### Returning User

1. Open app
2. Attempt auto-connect to last used TV
3. If connected, open remote interface immediately
4. If auto-connect fails, return to device select/reconnect flow
5. User can access Settings from remote screen to adjust layout anytime
6. If no device has been paired yet, remote opens in "no TV connected" state until first successful pairing

---

## 5. UI/UX Design Direction

### Theme: “Control Deck”

* Game-like, futuristic remote interface
* Smooth animations and transitions
* Haptic feedback on button press

### Layout Concept

Default remote layout baseline (grid coordinates, `[col,row]`):

* Power `[0,0]`, Pair/Wi-Fi `[4,0]`
* Home `[2,1]`, Play/Pause `[1,2]`, WWW `[3,2]`
* Volume rocker `[0,3]` (`1x3`, top edge anchored), Channel rocker `[4,3]` (`1x3`, top edge anchored)
* D-pad `[1,3]` (`3x3`, top-left anchor)
* Back `[0,6]`, Mute `[4,6]`
* Netflix `[1,7]`, Disney+ `[2,7]`, Prime Video `[3,7]`
* Search row `[0,8]` (`5x1`)

Control rendering details:

* Play/Pause is a compact `1x1` control with side-by-side icons (left play, right pause).
* D-pad arrows include directional padding tuning for visual centering:
    * Up: bottom +4
    * Down: top +4
    * Left: right +4
    * Right: left +4

### UX Principles

* Fast and responsive (low latency feel)
* Large, thumb-friendly buttons
* Dark mode by default
* Personalizable control layout for comfort and accessibility
* Keep critical control actions reachable with minimal taps

---

## 6. Technical Architecture

### Frontend

* Flutter (primary and chosen implementation stack)
* Architecture:

    * Service-based pattern with clear UI, domain, and communication layers

---

### Device Communication Layer

#### IR Control

* Android ConsumerIrManager API
* Predefined IR codes per brand

#### Wi-Fi Protocols

* Samsung (Tizen WebSocket API)
* LG (webOS WebSocket API)
* Hisense (VIDAA protocol variants; validation-gated support)
* Android TV / Google TV *(Post-MVP expansion candidate)*
* Roku (HTTP API) *(Post-MVP)*

#### Text Input Support

* Support sending text payloads for search and form entry on compatible TVs.
* If a device/protocol does not support text input, show a clear fallback message.
* Remote screen keyboard behavior should keep main layout stable (keyboard overlays content rather than resizing the remote canvas).
* Current implementation baseline: Samsung carries the in-app keyboard text path; LG webOS text send is still pending, so LG devices should not advertise in-app text capability until that transport lands.

#### Brand Adapter Strategy (MVP -> Post-MVP)

* MVP brand focus: Samsung, LG, Hisense (based on physically available test devices)
* Expand to additional brands when either:
    * in-house test hardware is available, or
    * verified external testers are available
* Prefer existing open-source/protocol implementations where stable and maintainable:
    * Samsung: Tizen WebSocket implementations are available in open source
    * LG: webOS WebSocket implementations are available in open source
    * Hisense: VIDAA integrations exist but are less standardized and may require experimental validation

#### Brand Readiness Matrix (Living)

| Brand | MVP Target | Protocol Maturity | Current Readiness | Validation Gate |
| --- | --- | --- | --- | --- |
| Samsung | Yes | High (well-known Tizen WebSocket patterns) | Core flow implemented; needs broader model verification | Validate TV-side approval prompt flow + token-auth reconnect + key commands + text input on physical TV |
| LG | Yes | Medium-High (webOS WebSocket patterns available) | Core command path still stubbed in-app; text input not wired yet (capability off until transport exists) | Validate SSL pairing + key commands on physical TV; add webOS text send then re-enable text input in UX |
| Hisense | Yes (best-effort) | Medium-Low (VIDAA implementations less standardized) | Experimental | Validate protocol compatibility per model before claiming support |
| Android TV/Google TV | No (Post-MVP) | High | Backlog candidate | Re-prioritize when hardware/tester bandwidth is available |

---

### Data Layer

* JSON and/or local on-device database (Flutter-friendly persistence)

Structure:
Brand → Model → Button → IR Code / API Command

---

### Backend (Optional)

* Firebase

    * Authentication
    * Firestore (user devices & configs)

---

## 7. Monetization

### Free Tier

* Basic remote functionality
* Ads (banner/interstitial)
* Initial ad placement policy:

    * Banner ads allowed on non-critical screens (home/device list/settings)
    * Interstitial ads should not interrupt active remote control sessions
    * No ads during first-time pairing critical steps

### Premium

* No ads
* Advanced features:

    * Voice control
    * Automation
    * Custom remotes

---

## 8. Risks & Challenges

### IR Hardware Limitation

* Many modern phones lack IR support

### TV Compatibility

* Different brands use different protocols

### Network Dependency

* Requires same Wi-Fi network

### Permissions Friction

* Especially on iOS (local network permissions)

---

## 9. MVP Scope Recommendation

Start lean:

* Android only
* Wi-Fi only (skip IR initially)
* Support:

    * Samsung
    * LG
    * Hisense (best-effort based on protocol/device validation)
* Features:

    * Basic remote controls
    * Text input keyboard for search/forms
    * Manual pairing
    * Save and auto-reconnect last used device
    * Settings access with per-device editable grid layout persistence

Explicitly out of MVP:

* IR signal database and "Does this work?" IR testing flow
* Cloud remote access
* iOS app release
* Voice/gesture controls
* Widgets/wearables

---

## 10. Future Expansion

This project remains strictly focused on universal TV remote functionality.

In-scope future expansion for this project:

* Add more TV platforms/protocols
* Improve TV pairing success rate and reconnection reliability
* Expand TV-focused UX and customization features
* Improve compatibility coverage across TV brands/models

Out of scope for this project:

* Non-TV device remotes (for example: air conditioners, audio systems)
* Broad smart-home orchestration beyond TV control
* Cross-device universal remote ambitions outside TV

---

## 11. Development Phases

### Phase 1 — Vertical Slice

* Samsung + LG core command coverage
* Basic controls (power, volume, navigation)
* Text input keyboard for search
* Settings button and layout preset selection
* End-to-end working flow

---

### Phase 2 — Expansion

* Add/refine Hisense support with protocol validation gate
* Expand compatibility within Samsung/LG models
* Improve connection flow
* Save devices
* Multi-device quick switching

---

### Phase 3 — Polish

* UI animations
* Faster reconnection
* Better onboarding
* Refine ad pacing and placements based on UX feedback

---

## 12. Guiding Principle

Focus on:
Speed to market over perfection

Start with:
Android MVP with Samsung/LG first, then Hisense validation

Before expanding into:
Universal Remote for every TV available
