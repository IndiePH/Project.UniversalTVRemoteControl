# Unreal Stack Reference

Use this reference when generating skills for Unreal Engine developers.

## Defaults
- Engine: Unreal Engine (version should be stated when relevant).
- Languages: C++ and Blueprint (explicitly state expected split).
- Typical outputs: gameplay systems, editor tooling, content pipeline guidance.
- Architecture: module-oriented with clear runtime/editor boundaries.

## Skill Authoring Guidance
- Require explicit target layer: C++, Blueprint, or hybrid.
- For execution skills, define asset-touch scope (uasset/Blueprint/material/data table) early.
- Include build/test expectations when behavior changes (compile + automated tests where available).
- Keep guidance precise on reflection/macros (`UCLASS`, `USTRUCT`, `UPROPERTY`, `UFUNCTION`) only when relevant.

## Common Constraints
- Avoid unnecessary API/signature churn across modules.
- Avoid broad content rewiring unless requested.
- Preserve gameplay behavior for bug-fix/refactor skills unless task explicitly changes behavior.
- Keep changes local to requested feature/system boundaries.

## Output Patterns
- Meta skills: JSON intent, routing plan, context package, risk.
- Execution skills: JSON patch/spec proposals with assumptions and confidence.
- Reference skills: compact standards and targeted snippets.

## Validation Checklist
- Trigger description maps to Unreal scenarios (C++, Blueprint, gameplay framework, assets).
- Scope rules clearly separate code-only and asset-touching tasks.
- No Flutter/Unity-only terminology appears.
