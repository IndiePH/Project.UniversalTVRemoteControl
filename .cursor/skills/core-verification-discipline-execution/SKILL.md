---
name: core-verification-discipline-execution
description: Post-change Flutter verify: right-sized checks exact errors no false done.
license: Complete terms in LICENSE.txt
---

# core-verification-discipline-execution

MODE: VERIFY_EXEC
RULES: verification scope matches changed behavior; never pass if required checks not run; report failures verbatim; cannot run => blocked + next_action.
OUTPUT: checks run, pass/fail status, exact failures or skipped reason, residual risk, and next action.

PIPELINE: pick checks(UI|logic|platform) -> run analyze + relevant tests -> add targeted run/build if native touched -> aggregate -> next_action