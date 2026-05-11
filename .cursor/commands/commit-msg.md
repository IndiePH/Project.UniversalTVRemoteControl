# Commit message

Goal: generate a Conventional Commit message (`title` + `body`) from current git changes.

Hard rules:
- Do **not** run `git commit`.
- Exclude `.cursor/**` from analysis.
- If only `.cursor/**` changed, return: `No non-.cursor changes to summarize.`

Scope + inputs:
- Use tracked + untracked git changes, excluding `.cursor/**`.
- Include staged + unstaged non-`.cursor` changes.
- Use recent commits only to mirror local style when useful.

Output format:
- Title section: one line in Conventional Commit style: `<type>(<optional-scope>): <summary>`
- Body section: 1-2 short paragraphs on why + impact (not raw file list).
- Do **not** include literal labels `title:` or `body:`.
- Return title and body in **two separate fenced code blocks** (one copy button per block).

Conventional Commit guidance:
- Types: `feat|fix|refactor|perf|test|docs|build|ci|chore`
- Subject: imperative, concise, lowercase start, no trailing period.
- Keep title <= 72 chars when possible.
- Wrap body near 72 chars per line when possible.

Selection rules:
- Prefer: `fix` bug correction, `feat` user-visible capability, `refactor` behavior-preserving structure change, `test` test-only change, `docs` docs-only change outside `.cursor`.
- Add scope only when clear from touched module (e.g. `remote-control`, `di`, `tests`).
- If multiple unrelated change groups exist, choose dominant theme and mention secondary impact in body.

Return only:
1) First fenced code block containing only the commit title line
2) Second fenced code block containing only the commit body text

Paste: `commit-msg`
