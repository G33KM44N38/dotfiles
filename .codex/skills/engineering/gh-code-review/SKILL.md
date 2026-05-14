---
name: gh-code-review
description: Review branch or PR changes for bugs, regressions, security issues, and missing tests. Use when the user asks for a code review or comparison against main.
---

# GitHub Code Review

Use this workflow for review requests.

## Scope

- Default comparison target: `main` (prefer `origin/main` when available).
- If the user provides a PR URL/number, review that PR directly with `gh`.

## Workflow

1. Gather context:
- Current branch: `git branch --show-current`
- Changed files:
  - `git diff --name-only origin/main..HEAD` (fallback `main..HEAD`)
- Commit list:
  - `git log --oneline origin/main..HEAD` (fallback `main..HEAD`)
- Diff stats:
  - `git diff --stat origin/main..HEAD` (fallback `main..HEAD`)

2. If PR context exists:
- `gh pr view <pr> --comments --files`
- Include unresolved review concerns in findings.

3. Evaluate by severity:
- Correctness bugs first
- Behavioral regressions
- Security/privacy risks
- Performance risks
- Missing or weak test coverage

4. Return findings-first output:
- `High`, `Medium`, `Low`
- Include file references and concise fix suggestions for each finding.
- If no findings exist, state that explicitly and call out residual risks/test gaps.

## Output Contract

- Prioritize actionable issues over summary.
- Keep summaries brief.
- Use concrete file references like `path/to/file.ts:42`.
