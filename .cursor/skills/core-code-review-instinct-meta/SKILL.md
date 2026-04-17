---
name: core-code-review-instinct-meta
description: >
  Use to perform a focused pre-merge review for Flutter Android/iOS changes.
  Identifies behavior regressions, edge cases, and testing gaps before merge.
license: Complete terms in LICENSE.txt
---

# Core Code Review Instinct Skill (Meta)

## Purpose

Provide a risk-first Flutter review that prioritizes bugs, regressions, and missing validation over stylistic comments.

## Responsibilities

- Evaluate behavior correctness against intended user outcome.
- Identify null-safety, async, state, lifecycle, and platform-specific risks.
- Assess test coverage gaps and propose minimal additional tests.
- Produce severity-ranked findings with clear rationale.

## Hard Constraints

- Review and analysis only; no edits or command execution.
- Focus on correctness and risk first, style second.
- Do not report speculative issues without evidence.
- If no findings exist, state that explicitly and list residual risk.

## Required Output

Return only this JSON object:

```json
{
  "findings": [
    {
      "severity": "critical|high|medium|low",
      "area": "string",
      "issue": "string",
      "impact": "string",
      "recommended_fix": "string"
    }
  ],
  "testing_gaps": ["string"],
  "residual_risks": ["string"],
  "overall_assessment": "approve|needs_changes|blocked",
  "recommended_next_skill": "string"
}
```

## Algorithm

1. Compare expected behavior versus proposed implementation path.
2. Check data flow, async ordering, and state synchronization edges.
3. Evaluate Android/iOS differences (permissions, lifecycle, backgrounding) where relevant.
4. Rank findings by user impact and release risk.
5. Recommend the next execution skill only for actionable outcomes.
