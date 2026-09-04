# Worktree cleanup

The canonical executable is `~/.dotfiles/bin/worktree-chore`.
The installer links `~/.local/bin/worktree-chore` to it.
The `wtc` alias and the six-hour LaunchAgent use the same executable.

Preview scheduled cleanup:

```sh
worktree-chore --root /Users/boss/coding/work --automation --dry-run --no-fetch
```

This preview uses cached references. A later fetch can change the candidates.

Automation removes only clean worktrees merged into `origin/main` or `origin/release`.
Tracked changes, untracked files, and ignored files prevent removal.
This includes ignored dependencies and local configuration files.
Synced but unmerged branches remain available.
Manual mode can remove synced branches after confirmation.

Root mode never changes worktrees outside the selected root.
Discovery includes nested repositories, but skips Git internals, `node_modules`, `.venv`, and `.cache`.
Unregistered directories remain untouched.
The tool does not prune unrelated worktree registration records.

The tool protects workspace, pane, and agent paths from the queried Herdr session.
It resolves symbolic links before comparing paths.
Missing or invalid protection data stops cleanup.
This does not cover external editors or other Herdr sessions.
Workspace state can still change between revalidation and the Git operation.

Manual root scans display a combined plan before requesting confirmation.
Pulls use `--ff-only`, with fresh activity and cleanliness checks.
Failures return a nonzero exit status.
Each external command has a two-minute timeout.

Run checks:

```sh
go test -race -count=1 ./...
go vet ./...
```

The installer lives in `install/roles/worktree-chore`.
Its LaunchAgent scans `~/coding/work` every six hours with `--automation --fetch`.
