---
name: ux-constraints-awareness
description: Reviews user-facing designs for accessibility, platform expectations, UI states, and harmful UX patterns. Use before implementing Flutter screens, prompts, empty/loading/error states, touch interactions, or visible UI changes.
---

# ux-constraints-awareness

MODE: UX_REVIEW CURSOR_PORT
SOURCE: ux-constraints-awareness|pri:M|deps:[]|flags:[feature-validation,risk-analysis]|rules:[CL-1,PS-1,CL-4]
STANDALONE: no external policy-template reads; use this file, project rules, and local UI patterns.

SCOPE: before implementation of user-facing design. Evaluate against WCAG 2.1 AA, platform HIG expectations, and existing app design language; surface violations before commitment.

ENFORCE: flag dark patterns immediately (pre-checked opt-ins, confirm-shaming, misleading hierarchy, roach motel); check contrast, keyboard/focus access where relevant, text alternatives, labels, error messages, and touch target size; verify happy, error, empty, and loading states; justify design-system deviations; flag legal accessibility risk to risk-analysis and structural UX gaps to feature-validation.

PROHIBIT: happy-path-only review; deferring accessibility to QA without design intent; suppressing dark-pattern findings for business reasons; undocumented design-system deviations; UI implementation with missing required states.

ON_VIOLATION: CL4_detected -> flag risk-analysis -> block implementation. structural_inaccessibility -> flag feature-validation. missing_states -> block sprint commitment. legal_a11y_risk -> flag risk-analysis.

OUTPUT: UX risks, required states, accessibility checks, design deviations, blocked items, residual risk.
