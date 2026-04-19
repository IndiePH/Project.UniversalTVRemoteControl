---
name: core-step-decomposition-meta
description: Multi-part/high-risk Flutter task -> phased plan + checkpoints. JSON only. NO_EDITS NO_CMDS.
license: Complete terms in LICENSE.txt
---

# core-step-decomposition-meta

MODE: PLAN_ONLY NO_EDITS NO_CMDS
RULES: minimum safe phases; each phase needs concrete verification; parallel only when independent; blocked phases explicit.

OUTPUT_ONLY_JSON
```json
{"phases":[{"id":"P1","objective":"string","actions":["string"],"verification":["string"],"depends_on":[],"risk_level":"low|medium|high","needs_confirmation":false}],"critical_path":["P1"],"rollback_notes":["string"],"recommended_next_skill":"string"}
```

PIPELINE: classify ask(feature|fix|refactor|hardening) -> shortest safe path -> attach verify per phase -> add confirmation gates -> emit dependency-aware sequence