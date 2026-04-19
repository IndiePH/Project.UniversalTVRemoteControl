---
name: core-verification-discipline-execution
description: Post-change Flutter verify: right-sized checks exact errors no false done. JSON only.
license: Complete terms in LICENSE.txt
---

# core-verification-discipline-execution

MODE: VERIFY_EXEC
RULES: verification scope matches changed behavior; never pass if required checks not run; report failures verbatim; cannot run => blocked + next_action.

OUTPUT_ONLY_JSON
```json
{"status":"pass|fail|blocked","checks_run":[{"name":"flutter_analyze|flutter_test|targeted_run","command":"string","result":"pass|fail|skipped","evidence":"string"}],"failures":["string"],"skipped_with_reason":["string"],"risk_assessment":"low|medium|high","confidence":0.0,"next_action":"string"}
```

PIPELINE: pick checks(UI|logic|platform) -> run analyze + relevant tests -> add targeted run/build if native touched -> aggregate -> next_action