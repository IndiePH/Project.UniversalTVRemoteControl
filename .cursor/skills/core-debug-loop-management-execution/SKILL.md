---
name: core-debug-loop-management-execution
description: Hypothesis-driven Flutter debug Android/iOS. One minimal fix per iteration + evidence per attempt.
license: Complete terms in LICENSE.txt
---

# core-debug-loop-management-execution

MODE: DEBUG_LOOP
RULES: one unrelated fix per iteration max; each attempt needs hypothesis+verify; preserve non-failing paths; bounded no-improvement => blocked.
OUTPUT: repro summary, ranked hypothesis, minimal fix attempted, verification result, and resolved|blocked status.

PIPELINE: normalize repro -> rank hypotheses(likelihood x blast_radius) -> smallest fix -> re-verify -> loop resolved|blocked