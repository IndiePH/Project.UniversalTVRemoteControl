---
name: goal-task-tracking
description: Track approved goal state files and surface the next dependency-ready task. Use when the user explicitly continues a goal, references a goal file, asks for the next task, or ORCH-1 completes a tracked task.
---

# goal-task-tracking

MODE: GOAL_TRACK_EXEC CURSOR_PORT
STANDALONE: no external registry imports required; manage `goals/goal-[id].md` lifecycle directly.
SCOPE: Stage-1 on explicit user continuation signal; Stage-10 on orchestrator task-completion trigger. Manage `goals/goal-[id].md` lifecycle. Never activate proactively or via session-start scan.
OUTPUT: selected goal file, current task/completion update, write confirmation, next dependency-ready task, or explicit blocked reason.

ENFORCE: Activate only when explicit continuation signal OR task-completion trigger exists; never self-trigger. At Stage-1 identify target goal file from signal; if ambiguous and multiple in-progress files exist, surface disambiguation list and require explicit selection before loading. Load and validate goal state file before any operation; halt on missing/corrupt file. Surface next pending task whose full dependency chain is done, in declaration order. Log task activation on first load. At Stage-10 verify completion criteria before marking done; write status update atomically; confirm write before reporting completion. After each Stage-10 write, if all tasks done, set goal status complete, write update, emit explicit goal-completion signal. Log task completion events and state anomalies. Validate no partial writes; on write failure halt and retain previous state. Ensure task status updates do not affect other tasks or overall goal integrity.

PROHIBIT: Activating without explicit continuation signal or Stage-10 trigger; proactive session-start scan of `goals/`; marking task done without orchestrator confirmation; auto-selecting ambiguous goal; silently closing completed goal; auto-repairing corrupt state file; non-atomic state writes; surfacing task with incomplete dependency chain; modifying task objectives, names, or dependencies after file creation.

ON_VIOLATION: missing_state_file -> halt -> report_path -> offer `goal-task-decomposition`. corrupt_state_file -> halt -> report_parse_failure -> log_decision. dependency_deadlock -> surface_blocked_tasks -> request_user_resolution -> block_execution. ambiguous_signal_multiple_goals -> surface_disambiguation_list -> require_explicit_selection. write_failure -> halt -> report_error -> retain_previous_state -> do_not_declare_complete. goal_already_complete -> notify_user -> do_not_surface_next_task.
