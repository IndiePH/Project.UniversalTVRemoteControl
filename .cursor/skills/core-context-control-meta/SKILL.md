---
name: core-context-control-meta
description: Narrow Flutter work to minimal files/modules before edits. NO_EDITS NO_CMDS.
license: Complete terms in LICENSE.txt
---

# core-context-control-meta

MODE: SCOPE_ONLY NO_EDITS NO_CMDS
RULES: no repo-wide refactor for local ask; keep existing state architecture; no new deps unless required.

PIPELINE: infer layer(UI|state|data|platform) -> minimal targets -> neighboring risks -> platform deltas if material -> strict boundary