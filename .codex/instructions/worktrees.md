# Worktrees

One job: isolate agent work without changing the user's checkout.

## Rules

- Use linked-worktree isolation only for repositories already organized around Git worktrees.
- Keep the task in the current worktree when the current checkout is already linked.
- Reuse or create a task worktree with plain Git worktree commands when the repository is a bare worktree source.
- Work in the current checkout for an ordinary single-checkout repository.
- Do not introduce a worktree there unless the user explicitly asks.
- Do not create or open a Herdr workspace unless the user explicitly asks for Herdr.
- Never change the branch in the user's original worktree.
- Never mix new task changes into a dirty checkout.
- Preserve existing changes.
- Leave cleanup, migration, and removal to explicit user direction.
