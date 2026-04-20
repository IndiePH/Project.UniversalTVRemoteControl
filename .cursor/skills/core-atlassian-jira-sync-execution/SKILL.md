---
name: core-atlassian-jira-sync-execution
description: Jira sync workflow via Atlassian MCP. Import/update reference-driven tasks with safe transitions.
license: Complete terms in LICENSE.txt
---

# core-atlassian-jira-sync-execution

MODE: ATLASSIAN_EXEC
JIRA_MAP: deterministic issue titles/types from source references
JIRA_SAFETY: no bulk-destructive edits
JIRA_CONFIRM: ask before status/assignee/label changes when ambiguous
JIRA_HISTORY: preserve existing issue history
JIRA_REPORT: list created/updated/skipped + reason each

PIPELINE: read source references + workflow intent -> detect create vs update set -> apply Jira operations through Atlassian MCP -> verify keys/status/links/fields -> summarize delta + follow-up actions