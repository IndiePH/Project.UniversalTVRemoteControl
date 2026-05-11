---
name: goal-task-decomposition
description: Decompose goal-level user requests into approved sub-goals and atomic tasks, then write a goal state file. Use when a prompt is a broad goal, multi-step initiative, roadmap item, or ORCH-1 goal-level input requiring task breakdown before execution.
---

# goal-task-decomposition

MODE: GOAL_DECOMPOSE_EXEC CURSOR_PORT
STANDALONE: no external registry imports required; use `.cursor/skills/**/SKILL.md` discovery to validate task coverage.
SCOPE: Post-intent parsing on goal-level input. Decompose goal into sub-goals -> tasks via iterative user approval loop; write approved state file to `goals/goal-[id].md`; block execution until file write is confirmed.
OUTPUT: approved breakdown summary, goal state file path, decisions/exclusions logged, blocked gaps, and first pending task only after write confirmation.

ENFORCE: Verify goal-level input before activating; verify no existing state file for same goal. Elicit if vague OR unknowns block sub-goals; batch max 5 questions per turn; prioritize by sub-goal impact. Decompose until every leaf task is one atomic certain action; recurse on seq-step-dependency, deferred-decisions, context-drift, ambiguous-done, or silent-cascade. Warn if sub_goals>7 OR tasks_per_sub_goal>6; escalate to confirmation at depth 10. Each task must have one testable objective, declared deps, and risk_hint. Validate every task against available Cursor skills; invoke `skill-gap-detection` for unmatched tasks. Annotate legal/ethical risk before presenting. Surface undeclared costs/delivery risks before presenting breakdown. Present full breakdown before writing any file. State assumptions explicitly; never present inferred scope as confirmed. Iterate max 2 cycles; require unambiguous approval before writing. Log decomposition decisions, scope exclusions, accepted scope/tooling changes in goal state file decisions section. Detect circular deps before presenting; block approval until resolved. Confirm write succeeded before returning first pending task. Validate sub-goal traceability to stated goal; if no prior project goals exist, approved goal file becomes project goals definition.

PROHIBIT: Activating without goal-level input; writing state file before explicit approval; proceeding on file write failure; stopping before leaf-task certainty passes; exceeding depth 10 without escalation; silently resolving dependency conflicts; activating when same-goal state file exists; decomposing before blocking unknowns are resolved.

ON_VIOLATION: vague_goal_after_elicitation -> halt -> request_scope_narrowing -> block_execution. circular_dep_detected -> block_approval -> surface_cycle. skill_gap_detected -> invoke `skill-gap-detection` -> surface_gap_in_breakdown. iteration_limit_reached -> confirmation_gate -> block_file_write. file_write_failure -> halt -> report_error -> block_execution. existing_goal_file_detected -> surface_file -> invoke `goal-task-tracking`. depth_cap_reached -> confirmation_gate -> block_decomposition. elicitation_unanswered -> halt -> await_response -> block_decomposition.
