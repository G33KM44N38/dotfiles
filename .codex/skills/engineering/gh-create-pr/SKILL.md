---
name: gh-create-pr
description: Create a pull request from the current branch with a solid title, description, and test plan. Use when the user asks to open a PR.
---

# Create Pull Request

Use this workflow when the user asks to open a PR with GitHub CLI.

## Workflow

1. Validate environment:
- Ensure git repo: `git rev-parse --is-inside-work-tree`
- Ensure `gh` exists: `gh --version`
- Get current branch: `git branch --show-current`
- If on target branch, stop and ask for correct source branch.

2. Resolve target branch:
- If user provides one, use it.
- Otherwise default to `main`.

3. Analyze change set:
- Commits ahead:
  - `git log --oneline origin/<target>..HEAD` (fallback `<target>..HEAD`)
- Changed files:
  - `git diff --name-only origin/<target>..HEAD` (fallback `<target>..HEAD`)
- Summary stats:
  - `git diff --stat origin/<target>..HEAD` (fallback `<target>..HEAD`)

4. Draft PR content:
- Title: concise, user-facing, outcome-oriented.
- Body includes:
  - `Summary`
  - `Changes`
  - `Test Plan`
  - `Risks / Notes`

5. Create PR:
- `gh pr create --base <target> --title "<title>" --body "<body>"`
- If remote branch is missing, push first with upstream.

6. Report result:
- Return PR URL and a short summary of title/base/test plan.

## Guardrails

- Do not rewrite commit history unless user asks.
- If tests were not run, explicitly say so in `Test Plan`.
