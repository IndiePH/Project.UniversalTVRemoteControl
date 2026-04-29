---
name: skill-gap-detection
description: Detect missing agent capability after Cursor skill discovery finds no match, block improvisation, and propose a governed skill outline. Use when ORCH-1 reports missing capability, no skill matches parsed intent, or a planned task lacks skill coverage.
---

# skill-gap-detection

MODE: GAP_DETECT_EXEC CURSOR_PORT
STANDALONE: no external registry imports required; search `.cursor/skills/**/SKILL.md`, `.cursor/rules/*.mdc`, and available MCP tools/resources before confirming a gap.
SCOPE: ORCH-1 missing_capability failure or no Cursor skill/rule/MCP match for parsed intent. Confirm missing capabilities, produce governed skill outline, and block improvisation.
OUTPUT: discovery surfaces checked, gap classification, overlap decision, proposed skill outline, confirmation need, and blocked execution note.

ENFORCE: Re-validate intent and search all Cursor skill/rule/MCP discovery surfaces before confirming gap; distinguish genuine gap from misuse and reject false positives before escalation. Classify confirmed gap by phase, category, and risk level. Produce new skill outline in Cursor `SKILL.md` format before escalation. Require confirmation gate before any skill/rule change. Log every confirmed gap regardless of outcome. Block execution that would improvise outside discovered skills/capabilities.

PROHIBIT: Declaring gap without full discovery search and intent re-validation; proposing new skill whose SCOPE overlaps >50% with existing skill, recommend extension instead; proceeding with improvised behavior after confirmed gap; updating skills/rules without confirmation approval.

ON_VIOLATION: improvised_execution_without_gap_report -> block -> surface_gap -> confirmation_gate. proposed_skill_overlaps_existing -> recommend_extension -> version_or_refactor_existing_skill. registry_update_without_confirmation -> block -> abort. false_gap_declaration -> re-run_intent_parsing -> re-validate_before_escalating.
