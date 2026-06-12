---
name: pr-review-fix-loop
description: Run a two-pass GitHub pull request review and fix workflow. Use when the user asks Codex to review a PR with a subagent, then have the main agent review it too, implement required changes, push them, and reply to PR review comments or threads.
---

# PR Review Fix Loop

Use this workflow for PRs where review and remediation both matter.

## Workflow

1. Identify the PR:
- Prefer an explicit PR number or URL from the user.
- Otherwise resolve the current branch PR with `gh pr view`.
- Record PR number, title, base branch, head branch, and current branch.

2. Launch an independent review subagent:
- Ask it to review the PR for correctness bugs, regressions, security/privacy issues, performance risks, and missing tests.
- Pass only the PR identifier and repo path. Do not pass your own suspected findings.
- Require findings-first output with file/line references and concise fix suggestions.

3. Run the main-agent review:
- Inspect the PR yourself with `gh pr view`, `gh pr diff`, changed files, nearby tests, and relevant docs.
- Compare your findings with the subagent's findings.
- Keep only findings that are reproducible from the diff or surrounding code.
- If findings disagree, read more code until the decision is defensible.

4. Comment on the PR:
- If the user asked only for review comments, leave concise GitHub review comments and stop after reporting what was posted.
- If the user asked to fix review comments too, continue.
- Leave comments directly on the affected code lines whenever the issue maps to a changed diff line.
- Use a general review summary only for findings that GitHub cannot attach inline, and include path and line refs there.
- Include a merge readiness score in the posted review summary, using `Merge readiness: N/10` with a one-sentence rationale.
- Do not approve your own PR unless the user explicitly asks.

5. Implement fixes:
- Check `git status` before editing.
- Keep edits scoped to confirmed review findings and user-requested changes.
- Do not rewrite unrelated code or revert unknown changes.
- Add or update regression tests when the fix changes behavior.

6. Validate:
- Run the narrowest meaningful tests first.
- Run the repo-required gate before pushing when time allows.
- If validation is blocked, report the exact command and blocker.

7. Push and answer review comments:
- Push only when the user asked for fixes or PR updates.
- Reply to each actionable GitHub comment/thread with what changed and the file reference.
- Resolve threads only when the fix has landed and the thread is clearly addressed.
- Re-check PR status and open comments after replying.

## Subagent Prompt

Use this shape:

```text
Review PR <number-or-url> in <repo-path>. Focus on bugs, regressions, security/privacy risks, performance issues, and missing tests. Return findings first, ordered by severity, with file/line references and concise fix suggestions. Do not implement changes.
```

## Output

- Lead with findings or "No findings".
- Include the merge readiness score and rationale that was posted to the PR.
- Then list fixes made, tests run, push status, and PR comments replied to.
- Keep summary short.
