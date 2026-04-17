---
name: skill-creator
description: >
  Manual-only. Use only when the user explicitly asks to create or edit a skill.
  Script-driven skill authoring guide for generating, validating, and packaging
  solid skills across developer stacks.
license: Complete terms in LICENSE.txt
---

# Skill Creator

Script-first workflow: use Python tooling to scaffold, validate, and package skills.

## Core Intent
- Preserve the script-driven skill-creator workflow.
- Produce reliable, concise skills with clear triggers and constraints.
- Keep references stack-aware to avoid generic ambiguity.

## Independence Model
- This folder is self-contained and can be copied to other projects as-is.
- All required guidance lives under `skill-creator/references/*`.
- No dependency on external shared reference directories is required.

## Stack References (Primary)
- `references/stack-flutter.md` for Flutter/mobile/app scenarios.
- `references/stack-unity.md` for Unity gameplay/editor/tooling scenarios.
- `references/stack-unreal.md` for Unreal gameplay/systems/C++/Blueprint scenarios.
- `references/shared-execution.md` for generic execution-skill constraints/output policy.
- `references/shared-meta-consultation.md` for generic meta-skill consultation flow.
- `references/workflows.md` for sequence/branch authoring patterns.
- `references/output-patterns.md` for output templates and example-driven quality.

## Script-Driven Workflow (Required)
1. Identify stack and skill type (`meta`, `execution`, `reference`).
2. Scaffold:
   ```bash
   python scripts/init_skill.py <skill-name> --path <output-directory>
   ```
3. Author `SKILL.md` using the stack reference + workflow/output references.
4. Validate:
   ```bash
   python scripts/quick_validate.py <path/to/skill-folder>
   ```
5. Package:
   ```bash
   python scripts/package_skill.py <path/to/skill-folder> [output-directory]
   ```
6. Iterate until validation passes and instructions are unambiguous.

## Skill Shapes To Generate

### Meta Skill
- Title: `# <Name> Skill (Meta)`
- Sections: Purpose, Responsibilities, Hard Constraints, Required Output, Algorithm
- Behavior: analyze/route only; no edits or execution

### Execution Skill
- Title: `# <Name> Skill (Execution)`
- Sections: Responsibilities, Hard Constraints, Required JSON Output, Algorithm
- Behavior: minimal scoped proposals, no unrelated refactors, explicit confidence/risk

### Reference Skill
- Compact standards guide (2-5 sections)
- Add examples only if they increase correctness
- No forced JSON schema unless machine output is required

## Quality Bar
- Frontmatter is valid and trigger description is specific.
- Language is concise, imperative, and non-ambiguous.
- Constraints block unsafe or out-of-scope behavior.
- Output contract is parseable when structured output is required.
- Instructions are consistent with selected stack reference.

## Output Requirement For This Skill
When asked to create or edit a skill, provide:
1. generated or updated `SKILL.md`
2. stack-specific reference links used
3. validation result from `quick_validate.py`
4. packaging readiness (or `.skill` artifact path if packaged)
