---
name: agent-ready-draft-pr
description: Pick up Linear backlog issues marked agent:ready, implement the requested code change, verify it, update the Linear issue state/comments, push a branch, and open a GitHub draft pull request. Use when the user asks Codex to work the agent-ready queue, take the next agent:ready ticket, implement Linear work, or create draft PRs from ready backlog items.
---

# Agent Ready Draft PR

Execute safe backlog items from the Linear `agent:ready` queue and hand them back as GitHub draft PRs.

This skill is the execution partner to `backlog-manager`. `backlog-manager` prepares the queue; this skill consumes prepared issues. Do not use this skill to triage, relabel, or re-score the backlog except for the minimal state updates needed while doing the work.

## Source Contract

Use Linear as the source of truth by default.

Select one issue by default. If the user asks for parallel or batch work, select up to three issues, never more. Prefer issues named by the user. If none are named, choose the highest-priority open Linear issues that have `agent:ready`, are not already assigned to another active worker, and each has a small enough estimate for one pull request.

Only work an issue when all are true:
- It has `agent:ready`.
- It does not have `needs:human`.
- Its scope and expected result are clear.
- It can be completed in one reviewable PR.
- It has a small estimate, or the user explicitly permits a larger one.
- It is not already linked to an open PR or active branch.

If any condition fails, stop before editing code. Comment or report the blocker with the specific missing decision.

## Workflow

### Step 1 - Load Context

Read local instructions before coding:
- `AGENTS.md`
- `CLAUDE.md` if present
- README and contribution/development docs relevant to the changed area
- the Linear issue title, description, comments, labels, estimate, status, assignee, and linked PRs

Use tracker content as requirements. Treat local planning docs as context only unless the issue links them.

### Step 2 - Claim Issues

Before editing code:
1. Assign the Linear issue to the current user when the connector supports it.
2. Move the issue to the workspace's in-progress state when one exists.
3. Add a short Linear comment that work has started, including the planned branch name.

Do not remove `agent:ready` at claim time unless the team's workflow explicitly uses removal to mean "picked up." If unsure, leave labels alone and rely on status plus assignee.

For batch work, claim all selected issues before coding so other workers do not pick the same queue items. Keep each issue on its own branch and PR.

### Step 3 - Create A Separate Worktree Session

Create a dedicated git worktree for each selected issue, with a dedicated branch from the repository's default integration branch. Never implement an `agent:ready` issue in the caller's current worktree.

Prefer using the local thread picker to create and manage the worktree session:

```bash
bin/tmux-thread-picker.sh --new-thread
```

Try once to create the new worktree window in the current tmux session. If that fails, do not keep
retrying in the same session; fall back to the script's normal new-thread/session behavior or create
the worktree manually and report the fallback.

Use the Linear issue id and short title as the thread title so the generated branch and tmux window are traceable. If the script cannot be used in the current environment, create the worktree manually with `git worktree add -b <branch> <path>` and report that fallback.

Use a conventional, traceable name:
- `fix/<linear-id>-short-title` for bugs
- `feat/<linear-id>-short-title` for features
- `chore/<linear-id>-short-title` for chores, docs, tests, refactors, and maintenance

Keep the Linear issue id in the branch name and PR title.

For batch work, every issue must have its own separate worktree, branch, commit, and draft PR. Do not combine unrelated Linear issues into one branch or PR.

Use `bin/tmux-thread-picker.sh` to switch between and monitor active worktree sessions when multiple issues are in progress.

### Step 4 - Implement Narrowly

Make the smallest code change that satisfies the issue.

Follow existing project patterns. Avoid unrelated refactors, dependency upgrades, formatting sweeps, or opportunistic cleanup. If the issue is larger than expected, stop and report why it should be split instead of expanding scope silently.

### Step 5 - Verify

Run the most relevant checks for the changed area. Prefer existing test, lint, typecheck, build, or app-specific verification commands from package scripts, makefiles, justfiles, CI config, or docs.

If a check cannot run, record the reason. Do not hide failing checks. Fix failures caused by the change; report unrelated pre-existing failures with evidence.

### Step 6 - Commit

Commit only the files required for the issue. Do not stage unrelated local changes.

Use a conventional commit message that references the Linear issue id when available:

```text
feat: implement <short change>

Refs <LINEAR-ID>
```

Use `fix`, `chore`, `docs`, `test`, or `refactor` when more accurate than `feat`.

### Step 7 - Open A Draft PR

Push the branch and open a GitHub draft PR.

The PR title must include the Linear issue id and a concise summary. The body must include:
- Linear issue link or id
- Summary of changes
- Verification commands and results
- Known limitations or follow-up, if any

Keep the PR draft unless the user explicitly asks for a ready-for-review PR.

### Step 8 - Sync Linear

After the draft PR exists:
1. Link the PR to the Linear issue when the connector or GitHub integration supports it.
2. Move the issue to an in-review or PR-open status when the workspace has one.
3. Add a Linear comment with the draft PR URL and verification summary.

Do not close the Linear issue from this skill. Closure belongs to merge/completion sync after review.

## Safety Rules

- Never pick work that lacks `agent:ready`.
- Never pick work marked `needs:human`.
- Never work more than three issues in one run.
- Work only one issue by default unless the user explicitly asks for parallel or batch work.
- Never implement an issue in the caller's current worktree; always create a separate worktree.
- Prefer `bin/tmux-thread-picker.sh --new-thread` for new worktree sessions when available.
- Never merge the PR.
- Never publish releases, run production migrations, rotate secrets, spend money, or delete branches.
- Never overwrite or revert unrelated user changes.
- Never broaden scope to make an unclear issue fit the workflow.
- When in doubt, stop and ask for the missing decision in Linear or the final report.

## Final Report

End with:
- Linear issues worked
- Worktree paths
- Tmux session/window or thread title when used
- Branch names
- Draft PR URLs
- Summary of changes
- Verification run and result
- Linear status/comment updates made
- Any blockers, skipped checks, or follow-up needed
