---
name: core-code-review-instinct-meta
description: Pre-merge Flutter Android/iOS risk review. Structured findings. NO_EDITS NO_CMDS.
license: Complete terms in LICENSE.txt
---

# core-code-review-instinct-meta

MODE: REVIEW_ONLY NO_EDITS NO_CMDS
PRIORITY: correctness/regression/platform/test-gaps>style
EVIDENCE: no speculation; no findings=>state explicitly + residual_risks
OUTPUT: findings first by severity with file refs, then open questions, residual risks, and concise summary.

PIPELINE: expected_vs_impl -> async/state/lifecycle/null/platform deltas -> rank impact+risk -> add minimal tests -> next_skill iff actionable