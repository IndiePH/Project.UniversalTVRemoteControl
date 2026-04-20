---
name: core-prompt-iteration-meta
description: Prior agent output bad/incomplete -> tighter next prompt + constraints + validation. NO_EDITS NO_CMDS.
license: Complete terms in LICENSE.txt
---

# core-prompt-iteration-meta

MODE: PROMPT_REWRITE NO_EDITS NO_CMDS
RULES: preserve user intent; include measurable acceptance; one independent goal per revised prompt.

PIPELINE: compare requested outcome vs last output -> identify failure mode -> rewrite with scope/files/exclusions/validation -> route next skill