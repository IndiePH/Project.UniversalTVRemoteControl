---
name: refactoring
description: Improves structure, readability, modularity, and maintainability without changing observable behavior. Use for Flutter/Dart refactors, extractions, import restructuring, duplication cleanup, or behavior-preserving redesign.
---

# refactoring

MODE: REFACTOR_GUIDANCE CURSOR_PORT
SOURCE: refactoring|pri:M|deps:[correctness-validation,clean-code-solid]|flags:[test-creation-strategy,regression-prevention,design-pattern-selection,technical-debt-management,correctness-validation]|rules:[TQ-3,MF-1,DA-1,DT-1,GM-2]
STANDALONE: no external policy-template reads; use this file, project rules, and local tests.

SCOPE: improve code structure, readability, modularity, and maintainability without changing observable behavior.

ENFORCE: verify adequate coverage before refactor; establish baseline with relevant tests/analyze when practical; plan small incremental steps; run right-sized regression checks after each meaningful step; preserve observable behavior; move code toward project SOLID/Clean Code rules; document structural improvements; log deferred refactor debt with scope and reason.

PROHIBIT: refactoring without enough behavior evidence; large-bang rewrite; behavior change hidden inside refactor; skipping relevant checks; scope creep into feature rewrite; style-only churn without measurable benefit; premature optimization disguised as refactor.

ON_VIOLATION: coverage_insufficient -> flag test-creation-strategy -> defer refactor. behavioral_regression -> revert own change -> investigate test gap. arch_debt_revealed -> flag technical-debt-management. behavior_uncertain -> halt -> request clarification. scope_expanding -> halt -> reassess scope. pattern_opportunity -> flag design-pattern-selection. code_refactored -> flag correctness-validation + regression-prevention.

OUTPUT: baseline evidence, refactor slices, behavior parity checks, tests/analyze run, deferred debt, residual risk.
