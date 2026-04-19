---
name: core-code-review-instinct-meta
description: Pre-merge Flutter Android/iOS risk review. JSON-only findings. NO_EDITS NO_CMDS.
license: Complete terms in LICENSE.txt
---

# core-code-review-instinct-meta

MODE: REVIEW_ONLY NO_EDITS NO_CMDS
PRIORITY: correctness/regression/platform/test-gaps>style
EVIDENCE: no speculation; no findings=>findings=[] + residual_risks

OUTPUT_ONLY_JSON
```json
{"findings":[{"severity":"critical|high|medium|low","area":"string","issue":"string","impact":"string","recommended_fix":"string"}],"testing_gaps":["string"],"residual_risks":["string"],"overall_assessment":"approve|needs_changes|blocked","recommended_next_skill":"string"}
```

PIPELINE: expected_vs_impl -> async/state/lifecycle/null/platform deltas -> rank impact+risk -> add minimal tests -> next_skill iff actionable