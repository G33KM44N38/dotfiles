# Worktrees

One job: isolate agent work without changing the user's checkout.

## Branch and path naming

- All agents must follow this workflow for new task branches, whether using plain Git, a launcher, or Herdr. It takes precedence over branch-naming skills and templates.
- Generate an opaque random identifier of eight lowercase hexadecimal characters, for example `a7f3c29b`. Use it unchanged as the local branch name and the worktree directory basename.
- Do not derive the identifier from the prompt, title, tracker ticket, username, or timestamp. Do not add prefixes or descriptive suffixes.
- Before creation, check that neither the local branch nor the target path exists. Generate another identifier on collision; let Git fail safely if a concurrent creation wins. Never reuse or overwrite an unrelated checkout.
- Keep human-readable descriptions in the Herdr thread/workspace title and the PR title.
- At first publication, choose a short descriptive remote branch name, for example `fix/rappels-rendez-vous`. Check that the destination is not an unrelated existing remote branch before pushing.
- Push with an explicit mapping and set upstream tracking: `git push --set-upstream <remote> <local-id>:refs/heads/<remote-name>`.
- For subsequent pushes, read the configured upstream and reuse its remote and destination with an explicit refspec. Do not assume bare `git push` works with different names, and do not create a remote branch under the local identifier by accident.
- Create or locate the PR using the remote head branch. Verify the local branch, worktree basename, upstream, and PR head agree with this mapping.
- Preserve existing branches, paths, and upstream mappings unless the user explicitly requests migration.

## Isolation

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
