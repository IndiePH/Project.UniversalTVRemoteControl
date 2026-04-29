---
name: design-pattern-selection
description: Selects appropriate design patterns by problem shape, extension needs, existing architecture, and complexity cost. Use when considering Strategy, Adapter, registry, factory, observer/stream, or other pattern choices.
---

# design-pattern-selection

MODE: PATTERN_GUIDANCE CURSOR_PORT
SOURCE: design-pattern-selection|pri:M|deps:[correctness-validation,clean-code-solid]|flags:[refactoring,abstraction-domain-modeling,technical-debt-management,architecture-consistency]|rules:[DA-5,DA-2,DA-3,DA-7,DT-1,GM-2]
STANDALONE: no external policy-template reads; use this file, project rules, and local patterns.

SCOPE: select patterns based on problem domain, balancing abstraction, extensibility, consistency, and simplicity.

ENFORCE: identify what varies, what stays stable, and required extension points; check existing project patterns before adding new ones; evaluate candidate patterns by problem fit and complexity cost; reject complexity without real requirement; align pattern names and roles with domain concepts; prefer patterns over repeated high-level conditionals when variation is stable; document why chosen over simpler alternatives.

PROHIBIT: speculative future-proof patterns; pattern choice based on technical convenience rather than business meaning; architecture-inconsistent patterns without justification; complex pattern when simple solution is enough; applying pattern before problem recurs or structure is clear; recommendation without implementation guidance.

ON_VIOLATION: overengineering -> reject pattern -> recommend simpler solution. pattern_inconsistent -> flag architecture-consistency -> request ADR/decision. pattern_replacement -> flag refactoring. domain_needed -> flag abstraction-domain-modeling. patterns_equal -> request business priority clarification. pattern_deferred -> flag technical-debt-management -> document migration.

OUTPUT: problem forces, candidates considered, selected pattern, rejected alternatives, implementation guidance, residual risk.
