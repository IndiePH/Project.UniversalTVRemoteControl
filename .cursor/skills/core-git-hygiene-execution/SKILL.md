---
name: core-git-hygiene-execution
description: Commit-safe Flutter AI diffs: scope staging message checks. JSON only. Never commit unless user asked.
license: Complete terms in LICENSE.txt
---

# core-git-hygiene-execution

MODE: GIT_HYGIENE
RULES: commit only on explicit user request; no secrets/generated noise by default; no history rewrite unless asked; keep unrelated dirty-tree edits untouched.

OUTPUT_ONLY_JSON
```json
{"commit_candidate_scope":"string","files_in_scope":["string"],"files_out_of_scope":["string"],"pre_commit_checks":["string"],"commit_message_draft":"string","risk_flags":["string"],"status":"ready|needs_confirmation|blocked"}
```

PIPELINE: scope required files -> exclude noise -> ensure verification evidence for behavior changes -> draft why-focused message -> readiness