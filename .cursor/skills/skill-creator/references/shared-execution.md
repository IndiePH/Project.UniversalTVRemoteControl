# Shared Execution Guidance

Use this reference when generating execution-oriented skills across any stack.

## Skill Routing (generic)
| Goal | Skill Type |
|------|------------|
| Implement new feature behavior from specification | Feature implementer |
| Fix compile/runtime errors with minimal behavior change | Code fixer |
| Improve readability/performance without behavior change | Code refactorer |
| Build or wire scenes/editors/components/content setups | Scene/component builder |
| Produce machine-readable content specs only | Spec generator |

## Common Constraints
- Keep scope minimal and local to the request.
- Do not refactor unrelated areas.
- Preserve behavior unless the request explicitly changes behavior.
- Avoid public API changes unless required by the task.
- State assumptions instead of inventing missing requirements.

## Output Contract
- Return only valid output in the format defined by the generated skill.
- Use strict JSON schemas when machine parsing is expected.
- Include confidence/risk signals for non-trivial execution tasks.
- Do not include extra prose outside the required output envelope.

## Safety Boundary
- Do not perform destructive or irreversible actions by default.
- Flag high-risk edits and require explicit confirmation in the generated skill.
- Keep apply/review separation explicit when proposing patches or specs.
