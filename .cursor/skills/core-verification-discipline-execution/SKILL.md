---
name: core-verification-discipline-execution
description: >
  Use after Flutter code changes to enforce consistent validation. Runs required
  checks, reports failures precisely, and prevents premature "done" claims.
license: Complete terms in LICENSE.txt
---

# Core Verification Discipline Skill (Execution)

## Responsibilities

- Select right-sized verification based on change scope and risk.
- Run required Flutter checks and collect actionable failures.
- Distinguish passing, failing, and skipped checks with reasons.
- Produce a machine-readable verification report.

## Hard Constraints

- Keep verification scope aligned to changed behavior; no unnecessary full-suite runs.
- Do not claim success when required checks were not run.
- Report command failures exactly; do not paraphrase away errors.
- If commands cannot run, return a blocked status with next action.

## Required JSON Output

Return only this JSON object:

```json
{
  "status": "pass|fail|blocked",
  "checks_run": [
    {
      "name": "flutter_analyze|flutter_test|targeted_run",
      "command": "string",
      "result": "pass|fail|skipped",
      "evidence": "string"
    }
  ],
  "failures": ["string"],
  "skipped_with_reason": ["string"],
  "risk_assessment": "low|medium|high",
  "confidence": 0.0,
  "next_action": "string"
}
```

## Algorithm

1. Determine verification set from task type (UI-only, logic change, platform integration).
2. Run baseline checks (`flutter analyze`, relevant `flutter test` targets).
3. Add targeted run/build checks when platform behavior changed.
4. Aggregate results and classify overall status.
5. Return precise follow-up action for any failures or blocked checks.
