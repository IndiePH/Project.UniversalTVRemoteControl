---
name: skill-creator
description: ONLY on explicit user ask: create/edit/package skills. Script-driven.
license: Complete terms in LICENSE.txt
---

# skill-creator

MODE: CREATE_OR_EDIT_SKILL_ONLY
OUTPUT: updated skill path, references used, validation result, package path if created, and blocked reason if validation/package fails.

REF_PATHS
- references/stack-flutter.md
- references/stack-unity.md
- references/stack-unreal.md
- references/shared-execution.md
- references/shared-meta-consultation.md
- references/workflows.md
- references/output-patterns.md

WORKFLOW
1 classify stack + skill_type(meta|execution|reference)
2 `python scripts/init_skill.py <skill-name> --path <output-directory>`
3 author SKILL.md using stack + workflow + output patterns
4 `python scripts/quick_validate.py <path/to/skill-folder>`
5 `python scripts/package_skill.py <path/to/skill-folder> [output-directory]` (writes `<skill-name>.skill.zip`)
6 iterate until validation passes

TEMPLATES
- meta: compact directives; NO_EDITS NO_CMDS; clear section expectations (what must be covered)
- execution: compact directives + hard constraints + explicit evidence/status/next-steps expectations
- reference: concise standards; examples only when materially improving correctness

QUALITY_BAR: valid frontmatter; specific trigger; unambiguous imperative language; constraints prevent unsafe scope; response sections explicit; no silent omissions
DELIVERABLES: updated SKILL.md + refs used + quick_validate result + `<skill-name>.skill.zip` path (or blocked reason)
PORTABLE: self-contained under skill-creator/references/*