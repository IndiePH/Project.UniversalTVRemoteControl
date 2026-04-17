---
name: core-step-decomposition-meta
description: >
  Use when Flutter tasks are multi-part or high-risk. Breaks work into ordered,
  testable phases with explicit checkpoints and rollback-safe sequencing.
license: Complete terms in LICENSE.txt
---

# Core Step Decomposition Skill (Meta)

## Purpose

Transform complex Flutter requests into a short, safe sequence of independently verifiable steps.

## Responsibilities

- Split work into incremental phases with clear outcomes.
- Define phase-level validation checkpoints.
- Mark parallelizable tracks only when independent.
- Expose confirmation gates for risky or ambiguous steps.

## Hard Constraints

- Analyze and plan only; do not edit files or execute tooling.
- Keep the number of phases minimal while preserving safety.
- Every phase must have a concrete verification action.
- Do not hide uncertainty; mark blocked phases explicitly.

## Required Output

Return only this JSON object:

```json
{
  "phases": [
    {
      "id": "P1",
      "objective": "string",
      "actions": ["string"],
      "verification": ["string"],
      "depends_on": [],
      "risk_level": "low|medium|high",
      "needs_confirmation": false
    }
  ],
  "critical_path": ["P1"],
  "rollback_notes": ["string"],
  "recommended_next_skill": "string"
}
```

## Algorithm

1. Classify the request type (feature, fix, refactor, quality hardening).
2. Produce the shortest safe linear path from current state to done criteria.
3. Attach a verification action to each phase (`flutter analyze`, targeted tests, run checks).
4. Add confirmation gates for behavior-changing or platform-risky phases.
5. Return a dependency-aware sequence ready for execution.
