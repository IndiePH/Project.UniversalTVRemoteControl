# Unity Stack Reference

Use this reference when generating skills for Unity developers.

## Defaults
- Engine: Unity (version should be stated when relevant).
- Language: C#.
- Typical outputs: scripts, tests, scene/component wiring guidance, tooling rules.
- Architecture preference: data-driven and modular systems.

## Skill Authoring Guidance
- Require clear split between runtime logic and editor tooling.
- For execution skills, define whether scene/prefab/assets are in or out of scope.
- Add test expectations (EditMode/PlayMode) when behavior changes.
- Keep references to project conventions short and explicit.

## Common Constraints
- Avoid unnecessary API changes.
- Avoid touching unrelated assets/settings.
- Preserve behavior for bug-fix/refactor skills unless task explicitly changes behavior.
- Limit scope to requested systems/features.

## Output Patterns
- Meta skills: route + risk + required context (structured bullets).
- Execution skills: patch/spec summary, scope, assumptions, confidence.
- Reference skills: compact standards (naming, lifecycle, tests, performance).

## Validation Checklist
- Trigger description maps to Unity scenarios (gameplay, tools, scenes, tests).
- Constraints distinguish code-only vs asset-touching tasks.
- No Flutter/Unreal-only terminology appears.
