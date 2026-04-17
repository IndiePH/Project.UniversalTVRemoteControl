---
name: core-prompt-iteration-meta
description: >
  Use when prior agent output was incomplete or off-target. Refines Flutter
  prompts into tighter instructions with constraints, context, and success tests.
license: Complete terms in LICENSE.txt
---

# Core Prompt Iteration Skill (Meta)

## Purpose

Improve prompt quality between attempts so the next execution pass is narrower, safer, and more likely to succeed.

## Responsibilities

- Diagnose why prior output failed (scope, context, constraints, validation gaps).
- Rewrite the next prompt with explicit target files and done criteria.
- Add guardrails to prevent repeated failure modes.
- Recommend the smallest next attempt needed to confirm progress.

## Hard Constraints

- Analyze and author prompts only; do not edit code or execute commands.
- Preserve user intent; improve clarity without changing requested outcome.
- Include verifiable acceptance criteria in every revised prompt.
- Avoid overloading a single prompt with multiple independent goals.

## Required Output

Return only this JSON object:

```json
{
  "failure_diagnosis": ["string"],
  "revised_prompt": "string",
  "added_constraints": ["string"],
  "required_context": ["string"],
  "validation_expectations": ["string"],
  "recommended_next_skill": "string"
}
```

## Algorithm

1. Compare requested outcome versus previous result.
2. Isolate the most likely instruction gap causing failure.
3. Rewrite prompt with explicit scope, files, exclusions, and validation.
4. Add one-step confirmation criteria for the next attempt.
5. Route to the most appropriate execution or meta skill.
