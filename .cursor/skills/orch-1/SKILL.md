---
name: orch-1
description: Semi-adaptive deterministic prompt lifecycle for intent parsing, skill selection, dependency resolution, planning, rule checks, confirmation gates, execution, logging, and completion validation. Use when prompts are multi-step, high-risk, ambiguous, state-modifying, or explicitly mention ORCH-1/orchestrator lifecycle.
---

# ORCH-1

VERSION: 2.8.0
MODE: LIFECYCLE_EXEC CURSOR_PORT
SCOPE: Semi-adaptive deterministic skill execution lifecycle with micro-kernel invariants; applies per prompt, including follow-ups and confirmations.
STANDALONE: no external orchestrator imports required; use Cursor rules, skills, and MCP descriptors only.
OUTPUT: active stages, selected skills, risk/gates, rule conflicts, decision logs if any, completion state, and next pending action.

STAGES: 1.Intent-Parsing 2.Skill-Selection 3.Dependency-Resolution(Cond) 4.Task-Planning(Cond) 5.Pre-Execution-Rule-Check 6.Confirmation-Gate(Cond) 7.Skill-Execution 8.Post-Execution-Rule-Check(Cond) 9.Decision-Logging(Cond) 10.Completion-Validation
ACTIVATE: Dependency-Resolution IF skill_count>1 OR deps_declared. Task-Planning IF risk in {MEDIUM,HIGH} OR multi_step OR persistent_state_modified. Confirmation-Gate IF risk=HIGH OR rule_requires_confirmation OR irreversible_operation. Post-Execution-Rule-Check IF persistent_state_modified OR deployment_or_migration. Decision-Logging IF architectural_decision OR tradeoff_applied OR rule_override_approved.
LOAD: Stage 1 classify intent/type using Cursor rules, skills, and MCP descriptors. Stage 2 choose matching Cursor skill(s) by description/name; read skill file before applying. Stage 5 evaluate relevant `.cursor/rules/*.mdc` hard constraints. Stage 10 if active goal/task tracking exists, mark completed task and surface next pending task. Flag-triggered named skill -> load+execute before advancing; increment hop_counter per hop; reset on convergence. hop_counter>=4 -> pause, surface cycle path/unresolved condition/hop count, ask continue_or_stop; on_stop abort; on_continue resume without reset; unhandled=execution_error.
RULES: Pre-exec evaluate hard constraints; violation -> BLOCK -> surface -> confirm OR abort. Post-exec validate state compliance; violation -> BLOCK -> escalate_to_confirmation. Rules override skills.
CONFLICTS: 1.Skill-Dependency-Resolution 2.Rule-Enforcement 3.Confirmation-Gate 4.Abort. Confirmation overrides rule block ONLY IF rule explicitly permits.
RISK: LOW=reversible OR informational. MEDIUM=state_modifying AND recoverable. HIGH=irreversible OR destructive OR compliance_sensitive OR production_impacting. Risk escalates; never decreases.
INVARIANTS: preserve_declared_constraints=TRUE; detect_scope_drift=TRUE; contradiction_detected->escalate_to_confirmation; persist_approved_architectural_decisions=TRUE; stale_constraint_detected->prune_before_stage_4; memory_conflict->escalate_to_decision_logging.
COMPLETE IF: no_active_rule_violations AND no_pending_confirmation AND all_planned_steps_executed. IF active_goal_session -> mark_task_done -> surface_next_pending_task.
FAILURE: dependency_conflict_unresolved->escalate_to_confirmation; rule_violation_without_override->abort; missing_capability->trigger skill-gap-detection; goal_level_input->trigger goal-task-decomposition and block Stage 2; explicit_continuation_signal->trigger goal-task-tracking and surface next task; unresolvable_conflict->abort.
VERSIONING: MAJOR=stage_order_changed OR lifecycle_semantics_changed OR checkpoint_repositioned OR completion_criteria_altered. MINOR=activation_logic_extended OR escalation_path_added OR risk_classification_extended OR dynamic_loading_changed. PATCH=non_behavioral_clarification.
