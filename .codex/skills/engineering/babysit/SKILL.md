---
name: babysit-pr
description: Get a pr ready to merge. Use when asked to babysit, watch, or follow a PR.
---

# Babysit PR

The pr you are doing this for is:

- If you are in a branch with a remote pr on it already, that one
- If the user includes a specific pr in their request, babysit that one

The end state here is:

- The PR doesn't have merge conflicts with the target branch
- The CI checks are green

Steps to take:

1. Watch the PR for CI and code review. Read the full review findings and check them against the code before deciding which to fix or skip.
2. When issues come in, fix them locally then commit and push them up
3. Wait for the checks to run again, if there are more issues, repeat step 2, otherwise move on to the next step
4. Give the user a concise summary of the changes you made to fix the pr and a concise list of things the PR actually does

## Review handoff

When the user asks for an extra review, or requests both skills, run [pr-review-fix-loop](../pr-review-fix-loop/SKILL.md) first. It owns the independent subagent review, main-agent review, and fixes. Then resume the monitoring loop here.

Reuse a completed two-pass review for the same PR and head commit in the current task. Do not launch another full review on every CI poll or fix commit. Check subsequent changes and new findings as needed; repeat the full review only if the user requests it or the changes invalidate the earlier review.

Pass the PR, repository path, reviewed head SHA, findings, fixes, validation results, and remaining blockers between workflows. Keep the user's existing scope and authorization, including whether GitHub comments and replies may be posted. Babysitting alone does not request an extra two-pass review or authorize merging.
