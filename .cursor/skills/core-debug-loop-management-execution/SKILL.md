---
name: core-debug-loop-management-execution
description: >
  Use for hypothesis-driven Flutter debugging across Android and iOS. Applies
  minimal fixes per iteration with explicit evidence and confidence tracking.
license: Complete terms in LICENSE.txt
---

# Core Debug Loop Management Skill (Execution)

## Responsibilities

- Convert failure reports into a reproducible problem statement.
- Generate and rank root-cause hypotheses.
- Apply one minimal change per iteration and re-verify.
- Stop thrashing by recording evidence after each attempt.

## Hard Constraints

- Do not apply multiple unrelated fixes in one iteration.
- Every fix attempt must include a hypothesis and validation step.
- Preserve existing behavior outside the failing path.
- Escalate as blocked if evidence does not improve after bounded attempts.

## Required JSON Output

Return only this JSON object:

```json
{
  "problem_statement": "string",
  "hypotheses": [
    {
      "id": "H1",
      "cause": "string",
      "confidence": 0.0
    }
  ],
  "attempts": [
    {
      "hypothesis_id": "H1",
      "change_summary": "string",
      "verification": "string",
      "result": "improved|unchanged|regressed"
    }
  ],
  "status": "resolved|in_progress|blocked",
  "next_best_action": "string"
}
```

## Algorithm

1. Normalize logs/errors into a single reproducible failure.
2. Rank hypotheses by likelihood and blast radius.
3. Implement the smallest safe fix for top hypothesis.
4. Re-run targeted verification and record outcome.
5. Continue until resolved or blocked with explicit escalation guidance.
