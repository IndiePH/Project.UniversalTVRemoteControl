---
name: architecture-review-execution
description: Runs a pre-implementation architecture review for Flutter/Dart changes. Use when work may affect design principles, decoupling, dependency injection, design patterns, layer boundaries, service wiring, or broad refactors before editing code.
---

# architecture-review-execution

MODE: ARCH_REVIEW_EXEC
SCOPE: pre-implementation architecture review for request-scoped changes
RULES: load `.cursor/rules/architecture-governance.mdc` and relevant language/framework rules before editing
OUTPUT_CONTRACT: emit `ARCH_REVIEW` with risk, affected layers, dependency direction, preserved contracts, DI plan, pattern decision, scope limit, gate, and verify plan.

## Workflow

1. Classify architecture risk:
   - LOW: single leaf change; no new dependency or boundary movement
   - MEDIUM: new collaborator, service, interface, provider, repository, controller, state path, or test seam
   - HIGH: cross-layer flow, DI container/provider changes, many-file rename/move, persistence/network/platform boundary, broad refactor
2. Map current design:
   - affected layer(s): UI, application/domain, data/infrastructure, platform
   - dependency direction before/after
   - contracts/interfaces to preserve
   - existing project naming/patterns to follow
3. Choose minimal design:
   - constructor injection for required deps unless local convention says otherwise
   - factory/provider composition only at boundaries
   - no hidden singleton/global lookup in core logic
   - simplest pattern that improves clarity/testability/reuse now
4. Gate the change:
   - PASS: scope is bounded; dependencies remain explicit; pattern adds clear value
   - ASK: multiple valid designs, boundary conflict, or user intent unclear
   - BLOCK: broad refactor, inward dependency leak, hidden dependency source, or untestable coupling without explicit approval
5. Execute only after PASS or user confirmation.
6. Verify after edits:
   - relevant tests/lints run or documented as not run
   - no new boundary violation
   - new dependency seams are mockable
   - pattern rationale recorded when non-trivial

## Output Template

```markdown
ARCH_REVIEW:
- risk: LOW|MEDIUM|HIGH
- affected_layers:
- dependency_direction:
- preserved_contracts:
- DI_plan:
- pattern_decision:
- scope_limit:
- gate: PASS|ASK|BLOCK
- verify:
```

## Escalation

- ASK before editing if risk is HIGH.
- ASK if a broad refactor seems useful but not required.
- BLOCK if architecture-governance hard constraints would be violated.
- Keep review terse; do not create design docs unless user requests one.
