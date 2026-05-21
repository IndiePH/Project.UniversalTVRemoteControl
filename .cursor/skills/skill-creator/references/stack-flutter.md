# Flutter Stack Reference

Use this reference when generating skills for Flutter developers.

## Defaults
- Language: Dart.
- Targets: Android, iOS, Web, Desktop (as specified by requester).
- UI style: declarative widgets, composition over inheritance.
- State: prefer explicit choice (for example Provider, Riverpod, Bloc, Cubit).

## Skill Authoring Guidance
- Require explicit Flutter/Dart version assumptions when relevant.
- Separate UI concerns from state/business logic in examples and constraints.
- Include platform caveats (permissions, lifecycle, build flavors) only when needed.
- For execution skills, require test updates (`flutter test`) when behavior changes.

## SRP Decomposition
- Use single-responsibility steps: UI orchestration, pure Dart logic, painters, IO/session.
- For refactors, prefer focused files over expanding one StatefulWidget/service with mixed concerns.
- Trigger split when UI-only testing is forced, reasons-to-change diverge, or protocol/layout/gesture logic is interleaved.

## Common Constraints
- Avoid broad refactors in generated patches.
- Keep widget tree changes minimal and localized.
- Avoid adding dependencies unless explicitly required.
- Preserve existing architecture choice if one already exists.

## Output Patterns
- Meta skills: terse sections/bullets (intent, plan, risks, boundaries).
- Execution skills: change summary, files touched, verification, confidence/risk.
- Reference skills: concise standards with small code snippets.

## Validation Checklist
- Trigger description includes Flutter-specific scenarios.
- Instructions mention Dart/Flutter artifacts (`pubspec.yaml`, widgets, tests) only when relevant.
- No Unity/Unreal-only terminology appears.
