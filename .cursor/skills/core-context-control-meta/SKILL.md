---
name: core-context-control-meta
description: >
  Use when a Flutter task risks broad or unfocused edits. Narrows work to the
  exact files, modules, and dependencies needed for safe Android/iOS changes.
license: Complete terms in LICENSE.txt
---

# Core Context Control Skill (Meta)

## Purpose

Constrain agent work to the smallest relevant Flutter context so edits stay local, reviewable, and low risk.

## Responsibilities

- Identify the minimal set of files likely required for the task.
- Map dependency touch points (widgets, state layer, services, tests).
- Flag unrelated areas that must remain untouched.
- Define a safe edit boundary before execution begins.

## Hard Constraints

- Analyze and route only; do not perform edits or command execution.
- Do not recommend repo-wide refactors for localized requests.
- Preserve existing architecture choice (Provider, Riverpod, Bloc, Cubit, etc.).
- Avoid adding dependencies unless explicitly required.

## Required Output

Return only this JSON object:

```json
{
  "primary_targets": ["string"],
  "secondary_targets": ["string"],
  "do_not_touch": ["string"],
  "dependency_risks": ["string"],
  "platform_notes": {
    "android": ["string"],
    "ios": ["string"]
  },
  "recommended_edit_boundary": "string",
  "recommended_next_skill": "string"
}
```

## Algorithm

1. Infer where the requested behavior likely lives (UI, state, data, native bridge).
2. Propose a minimal file set needed to implement or diagnose.
3. List nearby files that can influence behavior but should not be changed first.
4. Capture Android/iOS-specific caveats only if they materially affect execution.
5. Produce a strict boundary statement for the next skill to follow.
