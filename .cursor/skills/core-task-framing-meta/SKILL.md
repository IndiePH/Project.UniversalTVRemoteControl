---
name: core-task-framing-meta
description: Ambiguous Flutter ask -> goal scope assumptions acceptance Android/iOS. JSON only. NO_EDITS NO_CMDS.
license: Complete terms in LICENSE.txt
---

# core-task-framing-meta

MODE: FRAME_ONLY NO_EDITS NO_CMDS NO_FALSE_DONE
RULES: do not invent requirements; unknowns go to assumptions/open_questions; keep scope minimal; include platform delta only when material.

OUTPUT_ONLY_JSON
```json
{"goal":"string","scope":{"in":["string"],"out":["string"]},"constraints":["string"],"acceptance_criteria":["string"],"assumptions":["string"],"open_questions":["string"],"recommended_next_skill":"string"}
```

PIPELINE: target behavior -> platform surface -> in/out boundaries -> measurable acceptance -> unknowns vs constraints -> route next skill