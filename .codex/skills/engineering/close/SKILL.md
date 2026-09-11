---
name: close
description: Close the current Git worktree and reclaim its disposable build files using a deterministic local script. Use when the user invokes $close or explicitly asks to close and clean the current worktree.
---

# Close

An explicit request to close this worktree authorizes the script's cleanup. Creating or discussing this skill does not authorize running it against a real worktree.

Run exactly once, from the conversation's current working directory:

```sh
python3 "$HOME/.codex/skills/engineering/close/scripts/close.py" --apply
```

For a preview requested by the user, replace `--apply` with `--dry-run`.

Do not read the script, scan the repository, fetch, consult trackers, install dependencies, or invent cleanup commands during routine use. The script discovers and validates the current worktree, checks safety conditions, deletes only validated disposable directories, trashes the remaining checkout, and unregisters that worktree. It preserves branches and global caches.

If no locally known remote branch contains `HEAD`, `--apply` reads the advertised branch names and tips of configured remotes, starting with `origin`. It fetches only relevant advertised refs: the configured upstream, a branch with the same local name, one branch whose tip equals `HEAD`, and the remote default branch. It stops as soon as a fetched ref proves publication. Each ref is fetched separately, so an unrelated rewritten branch cannot block closure. Explicit destinations work even with no fetch mapping, including in bare repositories. A deleted upstream can be verified through its merge into the default branch. If publication cannot be proved through these candidates, cleanup remains blocked.

Fetching updates only the selected remote-tracking branches and Git objects. It does not push, force updates, change local branches or tags, prune refs, run repository hooks, change configuration, or overwrite `FETCH_HEAD`; symbolic destinations are refused. Each remote command has a 30-second timeout and disables interactive credential prompts. Rejected ref updates, timeouts, recognized access/network failures and other Git failures are reported separately without echoing remote URLs or raw authentication errors. Existing local publication proof needs no network access.

The dry run remains read-only: if local publication proof is missing, it stops and explains that `--apply` will fetch before deciding whether closure is safe. Never perform a separate manual fetch to bypass this result. Squash/rebase merges alone do not prove the original commits are published; the original `HEAD` must still be reachable from a remote-tracking branch.

Recognized tooling belonging to the current Codex session and idle foreground login shells in its Herdr host do not block closure. The script verifies process ancestry, executable and tool entrypoint; a generic `node` or `codex` name is not enough. It reports these as `preserved_session_processes` and leaves them running. Development servers, other agents, shells with jobs, and unrecognized processes still block. This exception is part of the normal close authorization and does not require another confirmation.

An explicit close request also authorizes the script to quit Neovim editors in this worktree gracefully. After Git and artifact checks, it discovers sockets owned by the reported Neovim processes and verifies each server's PID, working directory and buffer state over Neovim RPC. It refuses to close an editor with modified buffers, listed file buffers outside this worktree or a running terminal job. Hidden and unnamed modified buffers are protected too. If identity or buffer state cannot be verified, the editor remains a blocker. No additional confirmation is needed for an editor that passes these checks.

The script requests `noautocmd qall` without `!`, automatic writes or exit autocmds, rechecking buffer state immediately before quitting. It never sends a termination signal, saves buffers or discards changes. It verifies the server has exited and reruns process and Git checks before deleting artifacts. Neovim's terminal UI may exit with its server; the shell is preserved and must satisfy the existing idle-shell guard. Closed server PIDs appear in `closed_neovim_servers`. The dry run reports open editors without closing them. This automatic Neovim shutdown is the sole editor exception; other process blockers remain unchanged.

If blocked by running processes, use the script's `processes` details to identify each blocker: PID, process name, executable, parent PID/name, and working directory. Explain which are shells, development servers, or Codex/browser tools when the metadata establishes that; leave unknown roles unknown. If a process has disappeared since the report, say so. Report executable names without command-line arguments or environment variables that may contain secrets.

For an older PID-only report, a targeted read-only lookup is allowed:

```sh
ps -p <comma-separated-pids> -o pid=,ppid=,comm=
lsof -a -p <comma-separated-pids> -d cwd -Fn
```

After identifying a remaining process blocker, or for any other blocker, report the exact reason and stop. Do not commit, push, kill processes, force removal, or bypass a guard. Only the script's verified, graceful Neovim shutdown described above is authorized; never replace it with a manual or forced quit. Do not close a Herdr pane or terminate this Codex session. On success, summarize the result and the surviving repository path; do not run further commands from the removed directory. Preserved session tools and shells may still point into the trashed checkout, so any later command must use the surviving repository path. APFS sharing means file sizes are not a promise of recovered physical space.
