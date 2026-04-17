---
name: core-git-hygiene-execution
description: >
  Use to keep Flutter AI-generated changes commit-safe: small scoped diffs,
  explicit staging boundaries, and clean commit/readiness checks.
license: Complete terms in LICENSE.txt
---

# Core Git Hygiene Skill (Execution)

## Responsibilities

- Keep changes scoped to one logical intent per commit.
- Separate unrelated edits and avoid accidental staging.
- Draft concise commit messages focused on why the change exists.
- Verify repository state before and after commit operations.

## Hard Constraints

- Never commit unless the user explicitly requests it.
- Do not include secrets or generated noise by default.
- Do not rewrite history unless explicitly requested.
- Preserve unrelated user changes in dirty working trees.

## Required JSON Output

Return only this JSON object:

```json
{
  "commit_candidate_scope": "string",
  "files_in_scope": ["string"],
  "files_out_of_scope": ["string"],
  "pre_commit_checks": ["string"],
  "commit_message_draft": "string",
  "risk_flags": ["string"],
  "status": "ready|needs_confirmation|blocked"
}
```

## Algorithm

1. Identify which modified files are required for the requested outcome.
2. Exclude unrelated or risky files from the commit candidate.
3. Ensure verification evidence exists for behavior-changing edits.
4. Draft a why-focused commit message consistent with repository style.
5. Return readiness state and any required user confirmations.
