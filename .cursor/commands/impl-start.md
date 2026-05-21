# Implementation start

In: Jira key|URL. Out: assignee/status transition report + implementation start summary.

MCP `plugin-atlassian-atlassian`.

Resolve: `TVREMOTE-NN` from key or URL.

Read: `getJiraIssue`.

Assign-to-me guard:
- If assignee != me (or empty), set assignee via `editJiraIssue`.
- If my accountId unknown, resolve with `lookupJiraAccountId` then assign.

Status guard:
- If status != `In Progress`, use `getTransitionsForJiraIssue` -> `transitionJiraIssue` (`In Progress`).

Then implement: minimal scoped edits + relevant verification.

Safety:
- If assignee update fails (permissions/account lookup), stop and report blocker.
- If `In Progress` transition unavailable, stop and report blocker.
- Do not transition to `Done` in this command.
- Jira writes allowed here: `editJiraIssue` (assignee), `transitionJiraIssue` (status) only.

Paste: `impl-start TVREMOTE-NN` · `impl-start https://yoxent.atlassian.net/browse/TVREMOTE-NN`
