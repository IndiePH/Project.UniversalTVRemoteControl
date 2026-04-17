---
name: core-task-framing-meta
description: >
  Use when a Flutter request needs precise framing before implementation.
  Converts ambiguous requests into clear goal, scope, assumptions, and
  acceptance criteria for Android/iOS delivery.
license: Complete terms in LICENSE.txt
---

# Core Task Framing Skill (Meta)

## Purpose

Create an unambiguous implementation brief for Flutter work so execution skills can act with minimal risk.

## Responsibilities

- Parse the user request into target outcome, constraints, and platform scope.
- Extract explicit in-scope and out-of-scope boundaries.
- Define acceptance criteria that can be validated with Flutter tooling.
- Surface assumptions and missing inputs that may block safe execution.

## Hard Constraints

- Analyze and route only; do not edit files, execute commands, or claim changes were made.
- Do not invent requirements; label unknowns as assumptions.
- Keep scope minimal and aligned to the user request.
- Mention Android and iOS impact when behavior differs by platform.

## Required Output

Return only this JSON object:

```json
{
  "goal": "string",
  "scope": {
    "in": ["string"],
    "out": ["string"]
  },
  "constraints": ["string"],
  "acceptance_criteria": ["string"],
  "assumptions": ["string"],
  "open_questions": ["string"],
  "recommended_next_skill": "string"
}
```

## Algorithm

1. Identify the feature/bug target and expected end-user behavior.
2. Determine platform surface (Android, iOS, shared Dart layer, or all).
3. Define strict boundaries and excluded work.
4. Draft measurable acceptance criteria (UI behavior, state behavior, test impact).
5. List unknowns separately from known constraints.
6. Recommend the next execution/meta skill to run.
