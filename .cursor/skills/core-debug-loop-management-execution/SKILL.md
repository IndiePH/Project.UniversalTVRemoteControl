---
name: core-debug-loop-management-execution
description: Hypothesis-driven Flutter debug Android/iOS. One minimal fix per iteration + evidence JSON.
license: Complete terms in LICENSE.txt
---

# core-debug-loop-management-execution

MODE: DEBUG_LOOP
RULES: one unrelated fix per iteration max; each attempt needs hypothesis+verify; preserve non-failing paths; bounded no-improvement => blocked.

OUTPUT_ONLY_JSON
```json
{"problem_statement":"string","hypotheses":[{"id":"H1","cause":"string","confidence":0.0}],"attempts":[{"hypothesis_id":"H1","change_summary":"string","verification":"string","result":"improved|unchanged|regressed"}],"status":"resolved|in_progress|blocked","next_best_action":"string"}
```

PIPELINE: normalize repro -> rank hypotheses(likelihood x blast_radius) -> smallest fix -> re-verify -> loop resolved|blocked