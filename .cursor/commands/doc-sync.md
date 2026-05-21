# Doc sync

In: Jira delta | shipped | plan-only. Out: minimal patches + report (`patched`|`skipped`+why/file).

MCP `plugin-atlassian-atlassian` → `getAccessibleAtlassianResources` (cloudId). Read: `getJiraIssue`|`searchJiraIssuesUsingJql`. Write: `editJiraIssue`|`transitionJiraIssue`|`addCommentToJiraIssue` **only** if user asked.

Default keys (none from user): `TVREMOTE-36`,`TVREMOTE-37` + all `TVREMOTE-*` under `references/implementation_tasks.md` → `Jira (project TVREMOTE)`.

`references/implementation_tasks.md` (drift-only): Jira block + Status Tracker / Next Up / Milestones lines with `TVREMOTE-*` or superseded umbrellas.

Other refs (iff gap; else skip+why): `references/changelog.md` (top `## YYYY-MM-DD`; `Changed`|`Added`|`Verification`); `references/product_specs.md`, `references/universal-tv-remote-info-and-req.md`, `references/compliance-and-release-requirements.md`, `references/goal-oneremote-lib-review.md` — only if product/req/compliance/lib-review text must match plan or shipped truth.

Skills: `core-atlassian-jira-sync-execution` · `core-doc-sync-after-implementation-execution` (under `.cursor/skills/`).

Hard: factual · minimal diff · keep each file’s heading/list voice.

Report: keys read; file→state+why.

Paste: `doc-sync pull [JQL|keys]` · `doc-sync shipped TVREMOTE-NN` · `doc-sync plan-only … no Jira`
