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
- Use `general-purpose` only; do not use `Explore` for required review judgment.
- Ask it to review the PR for correctness bugs, regressions, security/privacy issues, performance risks, and missing tests.
- Pass only the PR identifier and repo path. Do not pass your own suspected findings.
- Require findings-first output with file/line references and concise fix suggestions.
- A valid subagent response must contain a `Findings` section and either concrete findings or `No findings.` Tool-only output, empty output, `(subagent completed without a final message)`, or result previews without findings are invalid.
- Prefer `run_in_background: false` for the retry so the final answer returns inline; background agents can complete with only result previews/tool traces. If the subagent does not produce valid output, retry once with a fresh `general-purpose` subagent and the strict prompt below. If retry also fails, continue with the main-agent review and report the subagent failure explicitly.

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

8. Add visual artifacts when requested:
- Embed the artifact directly in a PR comment so it renders in the conversation.
- Send Markdown bodies with real newline characters. Never publish escaped `\\n` sequences as visible text.
- For private repositories, do not embed `raw.githubusercontent.com` repository images: unauthenticated rendering returns 404. Use an authenticated root-relative GitHub blob URL pinned to the commit SHA, for example `/owner/repo/blob/<sha>/path/image.png?raw=true`; GitHub preserves this as the image `src` and the browser supplies repository authentication. A genuine GitHub user attachment is also valid.
- If a repository image is suitable and publicly accessible, pin it to the PR head commit SHA, not a branch name. Branch names containing `/` make raw asset URLs ambiguous.
- After posting or editing the comment, read it back through GitHub and verify that the Markdown contains real line breaks and that no embedded asset returns 404.
- Keep the artifact source in the PR branch and label conceptual mockups as visual summaries rather than executable proof.

## Subagent Prompt

Use this shape:

```text
Review PR <number-or-url> in <repo-path>. Focus on bugs, regressions, security/privacy risks, performance issues, and missing tests. Do not implement changes.

You MUST end with a final answer in this exact shape:

Findings
- <severity> — <title>
  <file:line>
  Problem: <what can go wrong>
  Fix: <concise fix>

If there are no findings, use exactly:

Findings
No findings.

Tests run
- <commands run, or "Not run: read-only review">

Do not stop after tool use. Do not return tool names. Do not omit the final answer.
```

## Output

- Lead with findings or "No findings".
- Include the merge readiness score and rationale that was posted to the PR.
- Then list fixes made, tests run, push status, and PR comments replied to.
- Keep summary short.
