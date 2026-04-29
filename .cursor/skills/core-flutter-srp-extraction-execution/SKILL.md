---
name: core-flutter-srp-extraction-execution
description: Flutter SRP refactor playbook. Extract focused collaborators with behavior parity and minimal diff.
license: Complete terms in LICENSE.txt
---

# core-flutter-srp-extraction-execution

MODE: REFACTOR_EXEC
REFAC_PARITY: preserve behavior unless user changes scope
REFAC_SLICE: one extraction slice per iteration
REFAC_STYLE: match local naming/import conventions
REFAC_SCOPE: no scope creep; no new deps unless required
REFAC_VERIFY: analyze + relevant tests after each slice
OUTPUT: extraction slice, files touched, parity checks, analyze/test result, and residual risk.

PIPELINE: identify mixed-responsibility hotspots -> choose smallest stable split seam -> extract focused unit (ui|logic|painter|session|io) -> rewire callers with parity checks -> run analyze + relevant tests -> report residual risk