# Global Codex Instructions

This file is the catalog for global instructions. Detailed rules live in `/Users/boss/.dotfiles/.codex/instructions/`.

Read every matching file before you act. If no row matches, read `/Users/boss/.dotfiles/.codex/instructions/CONTEXT.md`.

Keep each conversation focused on one subject and one concrete expected outcome.
Identify both from the user's request and state them briefly when starting work.
If either is unclear, help the user formulate a focused request before expanding
the work. A cross-cutting subject may span several systems or disciplines as long
as every part directly serves the same outcome.

Watch for drift in both the user's requests and your own proposed work. As soon
as a new subject or a separate outcome appears, tell the user what is drifting
and restate the current subject and outcome. Suggest handling the new item in a
separate conversation or explicitly replacing the current focus. Do not silently
add it to the scope. Continue authorized work toward the current outcome unless
the user explicitly changes direction. Necessary substeps and clarifying questions
that serve the same outcome are within scope.

When opening images or screenshots for the user on macOS, use Shottr instead
of Preview. Use `open -a Shottr "<path>"` for PNG, JPEG, and GIF files.
For PDFs or formats Shottr does not support, use an appropriate viewer.

| When the task involves | Read |
|---|---|
| Render or Render credentials | `/Users/boss/.dotfiles/.codex/instructions/render.md` |
| GitHub, pull requests, CI, releases, reviews, or proof artifacts | `/Users/boss/.dotfiles/.codex/instructions/github.md` |
| Creating or updating tracker issues, including Linear issues | `/Users/boss/.dotfiles/.codex/instructions/tracking.md` |
| Deleting files or cleaning a workspace | `/Users/boss/.dotfiles/.codex/instructions/deletion.md` |
| macOS or iOS signing, identities, entitlements, or bundle IDs | `/Users/boss/.dotfiles/.codex/instructions/apple-platforms.md` |
| Computer use | `/Users/boss/.dotfiles/.codex/instructions/computer-use.md` |
| Worktrees, branches, naming, checkout isolation, Git pushes, or publishing a PR branch | `/Users/boss/.dotfiles/.codex/instructions/worktrees.md` |
| Herdr, panes, workspaces, or Codex agent launches | `/Users/boss/.dotfiles/.codex/instructions/herdr.md` |
| Status, planning, ownership, pending work, monitoring, or calendars | `/Users/boss/.dotfiles/.codex/instructions/personal-ops.md` |
| Keyboard layouts, Corne keys, device profiles, or keyboard flashing | `/Users/boss/.dotfiles/.codex/instructions/keyboard.md` |
| Architecture, scope, or implementation choices | `/Users/boss/.dotfiles/.codex/instructions/engineering-values.md` |
