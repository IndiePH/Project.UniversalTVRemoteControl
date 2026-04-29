---
name: core-step-decomposition-meta
description: Multi-part/high-risk Flutter task -> phased plan + checkpoints. NO_EDITS NO_CMDS.
license: Complete terms in LICENSE.txt
---

# core-step-decomposition-meta

MODE: PLAN_ONLY NO_EDITS NO_CMDS
RULES: minimum safe phases; each phase needs concrete verification; parallel only when independent; blocked phases explicit; for Flutter/Dart refactors separate UI shell, pure logic, and wiring/integration phases; keep one reason to change per unit; follow repo Dart/Flutter rules when present.
OUTPUT: dependency-aware phases with scope, verification per phase, confirmation gates, blockers, and parallelizable steps.

PIPELINE: classify ask(feature|fix|refactor|hardening) -> shortest safe path -> attach verify per phase -> add confirmation gates -> emit dependency-aware sequence