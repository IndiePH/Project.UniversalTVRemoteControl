---
name: core-doc-sync-after-implementation-execution
description: Sync implementation docs after code changes. Update only impacted references with parity to shipped behavior.
license: Complete terms in LICENSE.txt
---

# core-doc-sync-after-implementation-execution

MODE: DOC_SYNC_EXEC
DOC_SCOPE: docs only (no code unless user asks)
DOC_CONTENT: factual shipped behavior only
DOC_STYLE: keep existing structure/tone
DOC_DRIFT: no speculative roadmap expansion
DOC_VERIFY: mention only checks actually run

PIPELINE: inspect change scope + verified behavior -> map impacted docs -> patch status/changelog/goal references with consistent terms -> run consistency pass (dates/task ids/names) -> report changed docs + residual doc gaps