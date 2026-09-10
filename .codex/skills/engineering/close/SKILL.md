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

If blocked, report the exact reason and stop. Do not commit, push, kill processes, force removal, or bypass a guard. Do not close a Herdr pane or terminate this Codex session. On success, summarize the result and the surviving repository path; do not run further commands from the removed directory. APFS sharing means file sizes are not a promise of recovered physical space.
