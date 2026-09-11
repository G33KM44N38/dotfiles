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

Recognized tooling belonging to the current Codex session and idle foreground login shells in its Herdr host do not block closure. The script verifies process ancestry, executable and tool entrypoint; a generic `node` or `codex` name is not enough. It reports these as `preserved_session_processes` and leaves them running. Development servers, other agents, shells with jobs, and unrecognized processes still block. This exception is part of the normal close authorization and does not require another confirmation.

If blocked by running processes, use the script's `processes` details to identify each blocker: PID, process name, executable, parent PID/name, and working directory. Explain which are shells, development servers, or Codex/browser tools when the metadata establishes that; leave unknown roles unknown. If a process has disappeared since the report, say so. Report executable names without command-line arguments or environment variables that may contain secrets.

For an older PID-only report, a targeted read-only lookup is allowed:

```sh
ps -p <comma-separated-pids> -o pid=,ppid=,comm=
lsof -a -p <comma-separated-pids> -d cwd -Fn
```

After identifying a remaining process blocker, or for any other blocker, report the exact reason and stop. Do not commit, push, kill processes, force removal, or bypass a guard. Do not close a Herdr pane or terminate this Codex session. On success, summarize the result and the surviving repository path; do not run further commands from the removed directory. Preserved session tools and shells may still point into the trashed checkout, so any later command must use the surviving repository path. APFS sharing means file sizes are not a promise of recovered physical space.
