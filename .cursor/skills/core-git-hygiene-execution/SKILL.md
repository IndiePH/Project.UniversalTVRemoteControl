---
name: core-git-hygiene-execution
description: Commit-safe Flutter AI diffs: scope staging message checks. Never commit unless user asked.
license: Complete terms in LICENSE.txt
---

# core-git-hygiene-execution

MODE: GIT_HYGIENE
RULES: commit only on explicit user request; no secrets/generated noise by default; no history rewrite unless asked; keep unrelated dirty-tree edits untouched.
OUTPUT: readiness summary with included/excluded files, verification evidence, proposed commit message, and blockers if any.

PIPELINE: scope required files -> exclude noise -> ensure verification evidence for behavior changes -> draft why-focused message -> readiness