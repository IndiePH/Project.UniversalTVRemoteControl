---
name: core-context-control-meta
description: Narrow Flutter work to minimal files/modules before edits. JSON only. NO_EDITS NO_CMDS.
license: Complete terms in LICENSE.txt
---

# core-context-control-meta

MODE: SCOPE_ONLY NO_EDITS NO_CMDS
RULES: no repo-wide refactor for local ask; keep existing state architecture; no new deps unless required.

OUTPUT_ONLY_JSON
```json
{"primary_targets":["string"],"secondary_targets":["string"],"do_not_touch":["string"],"dependency_risks":["string"],"platform_notes":{"android":["string"],"ios":["string"]},"recommended_edit_boundary":"string","recommended_next_skill":"string"}
```

PIPELINE: infer layer(UI|state|data|platform) -> minimal targets -> neighboring risks -> platform deltas if material -> strict boundary